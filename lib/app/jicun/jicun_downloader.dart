////////////////////////////////////////////////////////////////////////////////
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）
// 本文件由即存（jicun）项目移植，做了宿主化改写：合并上游 downloader.dart 及其
// part(download_config / download_transport / download_naming / download_publish)
// 为单文件，并去掉 Kotlin 原生下载 / MediaStore / SAF / 音频标签，落盘改为
// 写入应用下载目录（详见各段注释）。版权与许可遵循上游 MIT License。
////////////////////////////////////////////////////////////////////////////////
// ─── 宿主化改写说明 ───
// 上游 downloader.dart 及其 part(download_config / download_transport /
// download_naming / download_publish)在此合并为单文件。移植取舍:
//  · 不移植 Kotlin 原生下载 / 前台服务 / MediaStore / SAF:宿主要求是
//    「纯 Dart Range 切段并行 + 段级重试 + 断点续传,保存到应用下载目录」,
//    Dart 引擎(上游 useDartEngine 那条路)就是生产路径。
//  · 不移植 audio_tags / media_date(音频内嵌标签、容器日期改写):依赖上游
//    自有的二进制工具链,对「下载到应用目录」非必需。
//  · 落盘改为写入应用下载目录(见 _publishToFile):Android 上是
//    Android/data/<包>/files/<save_dir_name>,iOS 是 Documents/<save_dir_name>。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'jicun_config.dart';
import 'jicun_download_logic.dart';

/// 记一条「这里故意吞掉了异常」(移植自上游 failure.dart)。
void jicunSwallow(String tag, Object error, [StackTrace? stack]) {
  if (!kDebugMode) return;
  debugPrint('[jicun-swallow:$tag] $error');
}

/// 下载内容的类型(移植自上游,去掉 MediaStore 的公共目录字段)。
enum MediaKind {
  /// 视频
  video('video'),

  /// 音频
  audio('audio'),

  /// 图集 / 图片
  image('image');

  const MediaKind(this.wireName);

  final String wireName;
}

/// 一条待下载的媒体(移植自上游,去掉音频标签字段)。
class DownloadItem {
  DownloadItem({required this.url, required this.fileName, required this.kind});

  final String url;

  /// 落盘用的文件名。下载途中会被 [_retag] 按真实内容改写(上游同款)。
  String fileName;

  /// 这条按哪一种媒体归档。
  final MediaKind kind;
}

/// 进度回调的参数。按字节算而不是按条数(上游同款)。
class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  double get fraction =>
      total <= 0 ? 0 : (received / total).clamp(0.0, 1.0).toDouble();
}

/// 用户点了「取消下载」。
class DownloadCancelled implements Exception {
  const DownloadCancelled();

  @override
  String toString() => '下载已取消';
}

/// 收一条要用的那一批的上下文(移植自上游 download_config.dart 的 FetchContext)。
class FetchContext {
  const FetchContext({
    required this.temp,
    required this.tuning,
    required this.batchItems,
    required this.onFraction,
    this.cancelled,
    this.onSize,
    this.client,
  });

  /// 分片临时文件落在哪个目录。
  final Directory temp;

  /// 这一份下载器的参数。
  final DownloadTuning tuning;

  /// 这一批下几条。单文件内部的段数要按它摊薄(见 [lanesPerItem])。
  final int batchItems;

  /// 这一条收到了多少(0~1)。
  final void Function(double) onFraction;

  /// 取消开关,为真时中止。
  final bool Function()? cancelled;

  /// 问出整条多大时回调一次。
  final void Function(int size)? onSize;

  /// 复用的连接池。
  final HttpClient? client;
}

/// 下载器的可调参数(移植自上游 DownloadTuning,默认值来自后台「解析配置」)。
class DownloadTuning {
  const DownloadTuning({
    this.concurrency = 4,
    this.segmentedFromBytes = 8 << 20,
    this.segmentBytes = 4 << 20,
    this.maxSegments = 32,
    this.connectionBudgetMs = 10000,
  });

  /// 同时下载的文件数(后台 max_concurrent,0~缺省取默认)。
  final int concurrency;

  /// 超过这个字节数才分段(上游 segmentedFromBytes)。
  final int segmentedFromBytes;

  /// 一段多大。
  final int segmentBytes;

  /// 一个大文件最多同时开几条 Range 连接。
  final int maxSegments;

  /// 一条连接最多收多久还没把当前这一段收完,就掐掉换一条。
  final int connectionBudgetMs;
}

/// 下载器(上游 Downloader 的 Dart 引擎版)。
class Downloader {
  Downloader({this.tuning = const DownloadTuning()});

  final DownloadTuning tuning;

  /// 一条最多等多久没有任何数据。卡住的连接靠它超时。
  static const Duration _idleTimeout = Duration(seconds: 30);

  /// 不知道某条多大时,按这个字节数估进总量。
  static const int _unknownSizeGuess = 1024 * 1024;

  /// 尾巴阈值与尾巴粒度(与上游同一套)。
  static const int _tailBytes = 32 << 20;
  static const int _tailChunkBytes = 1 << 20;

  /// 段级重试的账本参数:连着 4 次一个字节都没收到才算这一段废了。
  static const int _stallLimit = 4;
  static const int _chunkAttemptLimit = 40;

  static const int _tempStaleHours = 24;

  /// 这一批的第 [index] 条用的临时文件路径。
  static String _tempPath(Directory temp, int index) =>
      '${temp.path}/jicun_${DateTime.now().microsecondsSinceEpoch}_$index.part';

  /// 一条一条地下,全部走纯 Dart 引擎。
  ///
  /// [onProgress] 每收到一段数据回调一次;[onItemDone] 每条落盘成功后回调
  /// (返回最终文件);[cancelled] 为真时中止。某一条失败不影响其余条目,
  /// 全部结束后若有失败,抛出第一条失败的原因。
  Future<void> saveAll(
    List<DownloadItem> items, {
    required void Function(DownloadProgress) onProgress,
    void Function(int index, File file)? onItemDone,
    bool Function()? cancelled,
  }) async {
    final temp = await getTemporaryDirectory();
    final bytes = List<int>.filled(items.length, 0);
    final sizes = List<int>.filled(items.length, 0);
    var finished = 0;
    Object? firstError;

    var expected = Downloader._unknownSizeGuess * items.length;

    void report() {
      final network = bytes.fold<int>(0, (a, b) => a + b);
      final work = (expected > 0 ? expected : 1) * 2;
      final done = (network).clamp(0, work);
      onProgress(DownloadProgress(received: done, total: work));
    }

    report();

    void noteSize(int index, int size) {
      if (size <= 0 || size == sizes[index]) return;
      expected += size - sizes[index];
      sizes[index] = size;
      report();
    }

    final client = HttpClient();
    final lanesEach = math.max(
      1,
      lanesPerItem(tuning.maxSegments, items.length),
    );
    client.maxConnectionsPerHost =
        math.min(tuning.concurrency, items.length) * lanesEach;
    var next = 0;
    try {
      Future<void> worker() async {
        while (true) {
          if (cancelled?.call() ?? false) throw const DownloadCancelled();
          final index = next++;
          if (index >= items.length) return;
          final item = items[index];
          try {
            final file = await _fetchOverHttp(
              item,
              FetchContext(
                temp: temp,
                tuning: tuning,
                batchItems: items.length,
                onFraction: (f) {
                  final size = sizes[index] > 0
                      ? sizes[index]
                      : Downloader._unknownSizeGuess;
                  bytes[index] = (size * f).round();
                  report();
                },
                cancelled: cancelled,
                onSize: (size) => noteSize(index, size),
                client: client,
              ),
            );
            final published = await _publishToFile(item, file);
            finished++;
            bytes[index] = sizes[index] > 0 ? sizes[index] : bytes[index];
            noteSize(index, bytes[index]);
            report();
            onItemDone?.call(index, published);
          } catch (e) {
            if (e is DownloadCancelled) rethrow;
            firstError ??= e;
            if (kDebugMode) {
              debugPrint('[jicun-dl] 第 ${index + 1} 条失败: $e');
            }
          }
        }
      }

      await Future.wait([
        for (var i = 0; i < math.max(1, tuning.concurrency); i++) worker(),
      ]);
    } finally {
      client.close();
    }
    if (firstError != null && finished < items.length) {
      // 失败的条目不打断已成功的:这里把第一个失败原因报出去,由调用方决定提示。
      throw Exception(firstError.toString());
    }
    if (finished < items.length) throw const DownloadCancelled();
    onProgress(DownloadProgress(received: expected * 2, total: expected * 2));
  }

  /// 落盘:把下好的临时文件搬进应用下载目录(不进系统媒体库)。
  ///
  /// 目录 = 平台应用外部存储 / Documents 下的 [JicunSettings.saveDirName]
  /// (后台 save_dir_name 可配)。同名文件自动追加序号,绝不覆盖。
  /// 公共下载根目录:安卓优先 /storage/emulated/0（sdcard），失败降级应用目录。
  static Future<Directory> _publicBase() async {
    if (Platform.isAndroid) {
      for (final cand in ['/storage/emulated/0', '/sdcard']) {
        try {
          final d = Directory(cand);
          if (d.existsSync()) {
            // 可写探测:建一个探针文件
            final probe = File('${cand}/.jicun_write_test');
            await probe.writeAsString('t', mode: FileMode.append);
            await probe.delete();
            return d;
          }
        } catch (_) {}
      }
    }
    try {
      base = await getApplicationDocumentsDirectory();
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) return ext;
      }
      return base;
    } catch (e) {
      jicunSwallow('publish.dir', e);
      return getTemporaryDirectory();
    }
  }

  static Future<File> _publishToFile(DownloadItem item, File file) async {
    final base = await _publicBase();
    final dir = Directory('${base.path}/${JicunSettings.instance.saveDirName}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var name = item.fileName;
    var target = File('${dir.path}/$name');
    var i = 1;
    while (target.existsSync()) {
      final dot = name.lastIndexOf('.');
      final stem = dot <= 0 ? name : name.substring(0, dot);
      final ext = dot <= 0 ? '' : name.substring(dot);
      name = '${stem}_$i$ext';
      i++;
      target = File('${dir.path}/$name');
    }
    try {
      return await file.rename(target.path);
    } catch (e) {
      // rename 跨卷可能失败,退回复制
      jicunSwallow('publish.rename', e);
      await file.copy(target.path);
      if (file.existsSync()) file.deleteSync();
      return target;
    }
  }

  /// 应用下载目录的可读路径(给 UI 提示用)。
  static Future<String> downloadDirPath() async {
    final base = await _publicBase();
    return '${base.path}/${JicunSettings.instance.saveDirName}';
  }

  /// 清扫缓存目录里残留超过 24 小时的 .part 分片(移植自上游 sweepLeftovers 思路)。
  static Future<int> sweepLeftovers({Directory? temp}) async {
    try {
      temp ??= await getTemporaryDirectory();
      var n = 0;
      final cutoff = DateTime.now().subtract(
        const Duration(hours: _tempStaleHours),
      );
      if (!temp.existsSync()) return 0;
      for (final f in temp.listSync()) {
        if (f is! File) continue;
        if (!f.path.endsWith('.part')) continue;
        final st = f.statSync();
        if (st.modified.isBefore(cutoff)) {
          try {
            f.deleteSync();
            n++;
          } catch (e) {
            jicunSwallow('sweep', e);
          }
        }
      }
      return n;
    } catch (e) {
      jicunSwallow('sweep.all', e);
      return 0;
    }
  }
}

/// 这一批里第 [index] 条用的临时文件路径。
///
/// 名字只为唯一服务:下载任务之间、同一任务内的分片之间都不能撞。
String _tempPath(Directory temp, int index) =>
    Downloader._tempPath(temp, index);
Future<File> _fetchOverHttp(DownloadItem item, FetchContext ctx) async {
  // 走 dart:io 的 HttpClient 而不是 package:http —— 前者能复用连接池,
  // package:http 的 IOClient 每次 send 都可能另起一条连接。
  final http = ctx.client ?? HttpClient();
  // 落盘的临时名唯一即可(见 [_tempPath]);相册里的名字由收尾的 [_retag] 按
  // `item.fileName` 定,两者解耦,下载途中不会互相覆盖。
  var target = File(_tempPath(ctx.temp, 0));
  final stem = _stemOf(item.fileName);
  final segments = <String, File>{};
  try {
    final probe = await _probe(item.url, http, ctx.cancelled);
    if (probe.statusCode != 200 && probe.statusCode != 206) {
      unawaited(probe.drain<void>().catchError((Object _) {}));
      throw HttpException('HTTP ${probe.statusCode}', uri: Uri.parse(item.url));
    }
    // 整条大小:206 得从 Content-Range 里读,`contentLength` 只是那 1 字节。
    final total = _sizeOf(probe);
    ctx.onSize?.call(total > 0 ? total : 0);
    // 探针那一发就带着响应头,顺手把这条的真扩展名定下来 —— 见 [_extensionFor]。
    final probeExt = extensionForContentType(
      probe.headers.contentType?.mimeType,
      item.kind,
    );
    // 服务端认 Range(回 206 就算认,不要求有 Accept-Ranges)、文件又够大,
    // 才分段并行。认不出大小或不支持就退回单连接老路 —— 慢总比下不动强。
    if (probe.statusCode == 206 &&
        total >= ctx.tuning.segmentedFromBytes &&
        _acceptsRanges(probe)) {
      // 探针那 1 字节扔掉,连接强制关掉,别让脏连接回池子。
      unawaited(probe.drain<void>().catchError((Object _) {}));
      await _fetchSegments(
        item,
        http,
        target,
        segments,
        ctx,
        total,
        // 分片的临时名挂在目标文件名上(`X.<序号>.part`),末尾那个 `.part` 不能少 ——
        // 启动清扫就按它认"下载留下的临时物"(见 [sweepLeftovers]);传别的前缀会留下
        // 一堆清扫认不出的孤儿分片。
        target.uri.pathSegments.last,
      );
      target = _retag(target, item, stem, probeExt);
      return target;
    }
    if (probe.statusCode == 206) {
      // 探针只拿到那 1 字节,整条重新要一次。复用探针那条连接反而是错的 ——
      // 服务端可能只发它承诺的那一段。
      unawaited(probe.drain<void>().catchError((Object _) {}));
      final fresh = await (await http.getUrl(Uri.parse(item.url))).close();
      if (fresh.statusCode != 200) {
        unawaited(fresh.drain<void>().catchError((Object _) {}));
        throw HttpException(
          'HTTP ${fresh.statusCode}',
          uri: Uri.parse(item.url),
        );
      }
      await _fetchSingle(fresh, target, fresh.contentLength, ctx);
    } else {
      // 服务端对 Range 不理(回了 200),那这条连接上就是整个文件。
      await _fetchSingle(probe, target, total, ctx);
    }
    // 文件头比响应头可信(有些 CDN 的 Content-Type 是错的),所以最终以嗅探为准,
    // 嗅不出来才用探针那发的 Content-Type。
    target = _retag(target, item, stem, probeExt);
    return target;
  } catch (_) {
    // 失败或取消都不留半个文件
    if (target.existsSync()) target.deleteSync();
    for (final part in segments.values) {
      if (part.existsSync()) part.deleteSync();
    }
    rethrow;
  } finally {
    if (ctx.client == null) http.close(force: true);
  }
}

/// 探针:先要 1 个字节,把大小和服不服 Range 问清楚。
///
/// 用的是 `Range: bytes=0-0` 的 GET,不是 HEAD —— HEAD 看着更省,但它的
/// 响应流是另一种东西:在 Dart 里对 HEAD 响应 `await for` 一个字节都收不到
/// (实测),拿它当兜底那条路的内容源会写出一个 0 字节的文件,而且不报错。
/// 探出来的这个字节直接扔掉,连接也强制关掉,别把脏连接塞回池子。
Future<HttpClientResponse> _probe(
  String url,
  HttpClient http,
  bool Function()? cancelled,
) async {
  final request = await http.getUrl(Uri.parse(url));
  request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
  final response = await request.close();
  if (cancelled?.call() ?? false) {
    unawaited(response.drain<void>().catchError((Object _) {}));
    throw const DownloadCancelled();
  }
  return response;
}

/// 整条文件多大。200 用 `Content-Length`;206 得从 `Content-Range` 的
/// `bytes 0-0/12345` 里读 —— 206 的 `contentLength` 只是那一段的长度。
int _sizeOf(HttpClientResponse response) {
  if (response.statusCode == 206) {
    final value = response.headers.value(HttpHeaders.contentRangeHeader);
    final match = value == null
        ? null
        : RegExp(r'/(\d+)\s*$').firstMatch(value);
    if (match != null) return int.parse(match.group(1)!);
  }
  return response.contentLength;
}

/// 单连接收完一条。原来那条路,留着当兜底。
Future<void> _fetchSingle(
  HttpClientResponse response,
  File target,
  int total,
  FetchContext ctx,
) async {
  var received = 0;
  final sink = target.openWrite();
  try {
    await for (final chunk in response.timeout(Downloader._idleTimeout)) {
      if (ctx.cancelled?.call() ?? false) throw const DownloadCancelled();
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) ctx.onFraction((received / total).clamp(0.0, 1.0));
    }
    await sink.flush();
    await sink.close();
  } catch (_) {
    await sink.close();
    // 失败或取消都不留半个文件
    if (target.existsSync()) target.deleteSync();
    rethrow;
  }
}

/// 按 Range 把一条大文件切成几段并行收,收完按顺序拼成一个文件。
///
/// **判据全部来自 [download_logic]**(跨端规格,和原生侧共用同一份测试向量):
/// 认领哪一段([claimedChunkWithTail])、续传从哪一跳([resumeOffset])、这条连接该不
/// 该掐掉换一条([shouldRotateConnection])、这一段还要不要接着试([ChunkAttempts])、
/// 200 的响应算不算"我们要的那一段"([wholeFileAsRange])。这里只负责把字节搬进分片
/// 文件和拼装 —— 那几条判据错了不会崩,只会安静地下出坏文件(少一段、写重一段),所以
/// 不许在这个文件里再写一遍。
///
/// [stem] 只拿来给分片临时文件起名,和相册里的名字无关。
Future<void> _fetchSegments(
  DownloadItem item,
  HttpClient http,
  File target,
  Map<String, File> segments,
  FetchContext ctx,
  int total,
  String stem,
) async {
  var received = 0;
  // 排障用的分片埋点:同时在飞的段数到底是多少。真机上聚合速度只有 PC 的一半时,先看
  // 这里:maxInFlight 上不去是连接池/调度的事,上得去就是链路额度。
  var inFlight = 0;
  var maxInFlight = 0;
  var rotations = 0;
  final segWatch = Stopwatch()..start();
  // 进度按整条文件算:每个段收到多少都加进同一个计数,圆环才是一条直线
  void bump(int delta) {
    received += delta;
    ctx.onFraction((received / total).clamp(0.0, 1.0));
  }

  // 认领是**共享游标**:谁空谁领下一段,领完(返回 null)就收工。区间怎么切、尾巴怎么
  // 切小都在规格里(见 [claimedChunkWithTail])。认领号就是分片序号,拼装按它排序。
  var claims = 0;
  Chunk? claimNext() {
    final chunk = claimedChunkWithTail(
      claims,
      total,
      ctx.tuning.segmentBytes,
      Downloader._tailBytes,
      Downloader._tailChunkBytes,
    );
    if (chunk != null) claims++;
    return chunk;
  }

  // 分片名:目标名摘掉 `.part` 再拼 `.<认领号>.part`。
  //
  // 末尾那个 `.part` **必须留着**:启动清扫按"文件名以 .part 结尾"认下载留下的临时物
  // (见 [sweepLeftovers])。原来写的是 `$stem.part$index`(=`…_0.part.part0`),结尾既不
  // 是 `.part` 又多了一层后缀 —— 进程半路被杀时那些分片清扫永远扫不到,一直占着缓存。
  String partNameOf(int index) {
    const marker = '.part';
    final base = stem.endsWith(marker)
        ? stem.substring(0, stem.length - marker.length)
        : stem;
    return '$base.$index$marker';
  }

  Future<void> one() async {
    while (true) {
      if (ctx.cancelled?.call() ?? false) throw const DownloadCancelled();
      final index = claims;
      final chunk = claimNext();
      if (chunk == null) return; // 领完了
      final name = partNameOf(index);
      final part = File('${ctx.temp.path}/$name');
      segments[name] = part;
      if (part.existsSync()) part.deleteSync();
      final ledger = ChunkAttempts(
        stallLimit: Downloader._stallLimit,
        attemptLimit: Downloader._chunkAttemptLimit,
      );
      while (true) {
        // 这一段已经落在盘上的那部分不再重下(见 [resumeOffset])。
        final written = part.existsSync() ? part.lengthSync() : 0;
        final from = resumeOffset(written, chunk.start, chunk.end);
        if (from > chunk.end) break; // 这一段满了
        if (ctx.cancelled?.call() ?? false) throw const DownloadCancelled();
        final request = await http.getUrl(Uri.parse(item.url));
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=$from-${chunk.end}',
        );
        final response = await request.close();
        // 服务端可以忽略 Range 回 200 + 整条(RFC 7233),那种响应按偏移写会写坏 ——
        // 除非**区间本来就等于整条**(起点 0、长度也对得上),那时 200 的内容正是要的
        // 那一段(实测微信视频号就是回 200 而不是 206)。判据在规格里。
        final usable =
            response.statusCode == 206 ||
            wholeFileAsRange(
              response.statusCode,
              from,
              chunk.end,
              response.contentLength,
            );
        if (!usable) {
          unawaited(response.drain<void>().catchError((Object _) {}));
          // 接着试还是判死,交给账本:没有进展才算停摆(见 [ChunkAttempts])。
          if (!ledger.noteFailure(0)) {
            throw HttpException(
              '分段下载被拒:HTTP ${response.statusCode}',
              uri: Uri.parse(item.url),
            );
          }
          await Future<void>.delayed(Duration(milliseconds: ledger.delayMs));
          continue;
        }
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        final startedAt = segWatch.elapsedMilliseconds;
        var got = 0;
        var rotated = false;
        final sink = part.openWrite(mode: FileMode.append);
        try {
          await for (final block in response.timeout(Downloader._idleTimeout)) {
            if (ctx.cancelled?.call() ?? false) throw const DownloadCancelled();
            sink.add(block);
            got += block.length;
            bump(block.length);
            // 慢连接:收了半天还没把这一段收完就掐掉换一条(判据在规格里)。跳出循环
            // 会取消这条订阅,HttpClient 随即丢掉这条连接,不会塞回池子。
            if (shouldRotateConnection(
              chunk.start,
              written + got,
              chunk.length,
              segWatch.elapsedMilliseconds - startedAt,
              ctx.tuning.connectionBudgetMs,
            )) {
              rotated = true;
              break;
            }
          }
          await sink.flush();
          await sink.close();
        } catch (e) {
          await sink.close();
          if (e is DownloadCancelled) rethrow;
          // 半段留在盘上:下一次尝试从 [resumeOffset] 接着收,别删。
          if (!ledger.noteFailure(got)) rethrow;
          inFlight--;
          await Future<void>.delayed(Duration(milliseconds: ledger.delayMs));
          continue;
        }
        inFlight--;
        if (!rotated) break; // 这一段收完了 → 去领下一段
        rotations++;
        if (!ledger.noteFailure(got)) {
          throw HttpException(
            '这一段换了 ${ledger.attempts} 条连接还没收完:${chunk.start}-${chunk.end}',
            uri: Uri.parse(item.url),
          );
        }
        await Future<void>.delayed(Duration(milliseconds: ledger.delayMs));
      }
    }
  }

  // 开几条 worker:批量下大文件时按文件数摊薄(判据在规格里)。
  final lanes = math.max(
    1,
    math.min(
      ctx.tuning.maxSegments,
      lanesPerItem(ctx.tuning.maxSegments, ctx.batchItems),
    ),
  );
  try {
    await Future.wait([for (var i = 0; i < lanes; i++) one()]);
    if (kDebugMode) {
      debugPrint(
        '[dl-seg] 分片数=$claims 同时在飞最多=$maxInFlight 掐掉的连接=$rotations '
        '总用时=${(segWatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
      );
    }
  } catch (_) {
    for (final part in segments.values) {
      if (part.existsSync()) part.deleteSync();
    }
    rethrow;
  }

  // 按认领号顺序拼:认领号就是文件里的先后顺序(head 段从小到大,尾巴段接在后面)。
  final sink = target.openWrite();
  try {
    for (var i = 0; i < claims; i++) {
      await _append(sink, segments[partNameOf(i)]!);
    }
    await sink.flush();
    await sink.close();
  } catch (_) {
    await sink.close();
    rethrow;
  }
  for (final part in segments.values) {
    if (part.existsSync()) part.deleteSync();
  }
  // 少收了字节就是残件 —— 宁可报错也别把半个视频交给相册
  if (target.lengthSync() != total) {
    throw HttpException(
      '分段下载不完整:${target.lengthSync()}/$total',
      uri: Uri.parse(item.url),
    );
  }
}

Future<void> _append(IOSink sink, File source) async {
  await for (final chunk in source.openRead()) {
    sink.add(chunk);
  }
}

/// 服务端认不认范围请求。
///
/// **不能只看 `Accept-Ranges`** —— 抖音视频 CDN 就不回这个头,但它对
/// `Range: bytes=0-0` 明确回了 206,这就是认。实测真机:只看这个头会把
/// 360MB 的视频判成"不分段",退回单连接,白等。
bool _acceptsRanges(HttpClientResponse response) =>
    response.statusCode == 206 ||
    (response.headers.value(HttpHeaders.acceptRangesHeader) ?? '')
        .toLowerCase()
        .contains('bytes');
// 文件叫什么、后缀怎么定:扩展名嗅探(认字节也认 Content-Type)、标题清洗、文件名
// 长度控制。
//
// 归到这里的东西都**不碰网络也不碰平台通道** —— 输入是字节和字符串,输出是名字。

/// 原生给的 MIME(`video/mp4; charset=…`)→ 后缀(`.mp4`)。
///
/// 直接读 [_kMimeExt] 那张表,不走 `extensionForContentType` —— 后者要传一个
/// 媒体类型,而这里正是不确定类型的时候(图集里混着视频)。
///
/// **带点返回**:[_retag] 是拿 `stem + ext` 直接拼名字的(和
/// `extensionForContentType` 那条路同一个用法),这里少一个点就会存出
/// `标题mp4` 这种没有扩展名的文件。
String _extFromContentType(String? contentType) {
  if (contentType == null) return '';
  final mime = contentType.split(';').first.trim().toLowerCase();
  return _kMimeExt[mime] ?? '';
}

/// 文件名去掉后缀。`_retag` 拿它当"标题 + 批次序号"那一段,收尾时再按真实内容
/// 补后缀 —— 带着原后缀走会拼成 `X.mp4.mp4`。
String _stemOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  // dot <= 0 保护的是 `.hidden` 这种(整个名字就是后缀)和没有后缀的名字。
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}

/// 按真实内容给这条媒体定名字,并把临时文件改成同名,返回改名后的文件。
///
/// **为什么必须换**:`item.fileName` 的扩展名是解析期按 URL 猜的(见
/// lib/pages/preview.dart 的 `imageExt`),而头条所有图片直链都过 CDN 变换,路径以
/// `~tplv-tt-large.image`
/// 结尾,没有 `.gif` / `.jpg` 可猜 —— 猜不到就落到兜底值。动图因此被命名成静态图
/// 的后缀,部分看图软件不再播放动画,看起来就像"GIF 变 PNG 了"(实测:同一张
/// 4.23MB 的 GIF89a,只是名字错了)。文件内容一直是原样的,这里只改名字,不重新
/// 编码 —— 一旦解码再编码,动图必然被压成第一帧。
///
/// 改的是 **`item.fileName` 本身**:`publish` 拿它当 MediaStore 的
/// `DISPLAY_NAME`,只改临时文件的话相册里还是错后缀(实测就是这么漏过去的)。
///
/// 名字里那段 `.part` 也在这里掉:临时目录里它防的是"下了一半的文件被当成成品",
/// 收完这一步就不需要了。
///
/// [probeExt] 是下载前那一发探针响应里的 Content-Type,拿不到就是空串。
///
/// [stem] 是这条最终名字里"标题 + 批次序号"那一段,由调用方给 —— 不是从
/// `item.fileName` 里拆的:下载用的临时名和相册要用的名字现在是两回事(见
/// [_tempPath]),拆临时名会拆出临时名的前缀。
File _retag(File file, DownloadItem item, String stem, String probeExt) {
  final sniffed = _sniffExt(file);
  // 后缀三选一:
  //   1. 嗅探结果和这条声明的类型对得上 → 用嗅探值(视频的 `.mp4`、图的 `.webp`…);
  //   2. **声明是音频、容器又是 MP4 家族** → 按 `.m4a` 记。这一条不能少:纯音频的
  //      m4a(B 站 DASH 那条音频流、/api/audio 抽出来的那份)与视频共用同一个 `ftyp`
  //      盒子,嗅探只能给出 `.mp4` —— 那是"视频"的后缀。照它登记的话,一份音频会顶着
  //      `video/mp4` 进 `Music/`,媒体库要么拒收要么归档错。
  //   3. 其余对不上的用 Content-Type 那条:字节和用途不是一回事,不硬按内容改名。
  final String ext;
  if (sniffed == null) {
    ext = probeExt;
  } else if (_kindOfExt(sniffed) == item.kind) {
    ext = sniffed;
  } else if (item.kind == MediaKind.audio && _kIsoBmffExts.contains(sniffed)) {
    ext = '.m4a';
  } else {
    ext = probeExt;
  }
  // 后缀这一下可能比解析期猜的长(`.jpg` → `.webm`),总长由这里收口 ——
  // 解析期扣的是候选后缀里最长的那个,正常不会走到截断。
  final finalStem = _fitStem(stem, ext, _kMaxNameBytes);
  // 临时文件先腾地方:同一条被重新下过就可能占着这个名字
  final scratch = File('${file.parent.path}/${item.fileName}');
  if (scratch.existsSync()) scratch.deleteSync();
  if (ext.isEmpty) {
    // 认不出格式:名字照抄,只摘掉 `.part` 这个临时标记(一个字节的格式信息都给不出,
    // 解析期猜的后缀也就不必留了)。
    final plain = File('${file.parent.path}/$finalStem');
    if (plain.existsSync()) plain.deleteSync();
    return file.renameSync(plain.path);
  }
  final renamed = File('${file.parent.path}/$finalStem$ext');
  if (renamed.existsSync()) renamed.deleteSync();
  final moved = file.renameSync(renamed.path);
  item.fileName = '$finalStem$ext';
  return moved;
}

/// 读文件头几个字节认格式,认不出返回 null。
///
/// 中段文件里 `_retag` 拿到的就是文件开头,所以这里读出来的就是真格式。
String? _sniffExt(File file) {
  RandomAccessFile? handle;
  try {
    handle = file.openSync();
    final head = handle.readSync(16);
    return extensionForBytes(head);
  } catch (_) {
    // 文件不在了/读不动:交给上层按 Content-Type 或原名字处理,不在这里炸
    return null;
  } finally {
    handle?.closeSync();
  }
}

/// 文件头 → 扩展名。认不出返回空串。
@visibleForTesting
String extensionForBytes(List<int> head) {
  final b = head;
  bool at(int i, List<int> magic) {
    if (b.length < i + magic.length) return false;
    for (var k = 0; k < magic.length; k++) {
      if (b[i + k] != magic[k]) return false;
    }
    return true;
  }

  if (at(0, const <int>[0x47, 0x49, 0x46, 0x38])) return '.gif';
  if (at(0, const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return '.png';
  }
  if (at(0, const <int>[0xFF, 0xD8, 0xFF])) return '.jpg';
  if (at(0, const <int>[0x42, 0x4D])) return '.bmp';
  if (at(0, const <int>[0x1A, 0x45, 0xDF, 0xA3])) return '.webm';
  if (at(0, const <int>[0x66, 0x4C, 0x61, 0x43])) return '.flac';
  if (at(0, const <int>[0x4F, 0x67, 0x67, 0x53])) return '.ogg';
  if (at(0, const <int>[0x52, 0x49, 0x46, 0x46]) &&
      at(8, const <int>[0x57, 0x41, 0x56, 0x45])) {
    return '.wav';
  }
  if (at(0, const <int>[0x49, 0x44, 0x33]) ||
      at(0, const <int>[0xFF, 0xFB]) ||
      at(0, const <int>[0xFF, 0xF3])) {
    return '.mp3';
  }
  // RIFF 里还有 WEBP / AVI,两个都要看 offset 8 的 FOURCC
  if (at(0, const <int>[0x52, 0x49, 0x46, 0x46])) {
    if (at(8, const <int>[0x57, 0x45, 0x42, 0x50])) return '.webp';
    if (at(8, const <int>[0x41, 0x56, 0x49, 0x20])) return '.avi';
  }
  // HEIF/AVIF/MP4/MOV/M4A 共用一个盒子:offset 4 是 'ftyp',8 起是 brand
  if (at(4, const <int>[0x66, 0x74, 0x79, 0x70])) {
    final brand = String.fromCharCodes(
      b.sublist(8, b.length < 12 ? b.length : 12),
    );
    if (brand.startsWith('avif') || brand.startsWith('avis')) return '.avif';
    if (brand.startsWith('heic') ||
        brand.startsWith('heix') ||
        brand.startsWith('mif1')) {
      return '.heic';
    }
    if (brand.startsWith('qt')) return '.mov';
    if (brand.startsWith('M4A')) return '.m4a';
    // brand 认不出(CDN 常见):长度够了照样按 MP4 记 —— 猜错了也是所有播放器
    // 都吃的容器,比留着 .part 强
    return b.length >= 16 ? '.mp4' : '';
  }
  return '';
}

/// 认得出的扩展名 → 它是哪一种媒体。表只用来**校验**猜出来的后缀和这条的类型对不对
/// 得上,所以没法全(不在表里的就当"未知",不阻断改名)。
const Map<String, MediaKind> _extKind = <String, MediaKind>{
  'jpg': MediaKind.image,
  'jpeg': MediaKind.image,
  'png': MediaKind.image,
  'gif': MediaKind.image,
  'webp': MediaKind.image,
  'avif': MediaKind.image,
  'heic': MediaKind.image,
  'heif': MediaKind.image,
  'bmp': MediaKind.image,
  'tif': MediaKind.image,
  'tiff': MediaKind.image,
  'mp4': MediaKind.video,
  'm4v': MediaKind.video,
  'mov': MediaKind.video,
  'webm': MediaKind.video,
  'mkv': MediaKind.video,
  'avi': MediaKind.video,
  'flv': MediaKind.video,
  'ts': MediaKind.video,
  'mp3': MediaKind.audio,
  'm4a': MediaKind.audio,
  'aac': MediaKind.audio,
  'wav': MediaKind.audio,
  'flac': MediaKind.audio,
  'ogg': MediaKind.audio,
  'oga': MediaKind.audio,
  'opus': MediaKind.audio,
};

/// ISO-BMFF(MP4 家族)容器的后缀。
///
/// 音频和视频共用这一套盒子,光看文件头分不出谁是谁 —— 纯音频的 m4a 一样以 `ftyp`
/// 开头(实测 B 站那条纯音频流和抽轨出来的 m4a 都是 `ftypiso5`)。所以判类型不能只看
/// 后缀,得结合这条声明的媒体类型(见 [_retag])。
const Set<String> _kIsoBmffExts = <String>{'.mp4', '.m4v', '.mov'};

/// 扩展名属于哪一种媒体,表里没有返回 null(当"未知")。
MediaKind? _kindOfExt(String ext) =>
    _extKind[ext.startsWith('.') ? ext.substring(1) : ext];

/// Content-Type → 扩展名,认不出(包括 `application/octet-stream` 这种没信息的)返回空串。
///
/// 头条动图那条链路的响应头就是 `image/gif`,而 URL 后缀是 `~tplv-tt-large.image`,
/// 这是唯一能拿到正确后缀的地方 —— 所以下载器要拿响应头定名字,不能只信 URL。
@visibleForTesting
String extensionForContentType(String? contentType, MediaKind kind) {
  final mime = (contentType ?? '').split(';').first.trim().toLowerCase();
  final ext = _kMimeExt[mime];
  // 类型对不上就不用:标着 video 却回 image/gif 的地址,按音频/视频登记进媒体库会
  // 被系统拒收(见 MainActivity 的 mimeTypeOf),不如让原名字兜底。
  return ext != null && _kindOfExt(ext) == kind ? ext : '';
}

/// Content-Type → 扩展名(带点)。只认这几个,认不出返回 null。
///
/// 抽成顶层常量是因为有两处要用:上面按媒体类型校验的那条路,以及原生下载回来
/// 定后缀那条路(见 [_extFromContentType])—— 后者拿到的 MIME 不一定
/// 对应已知类型,所以直接查表、不做类型校验。
const Map<String, String> _kMimeExt = <String, String>{
  'image/gif': '.gif',
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/pjpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/avif': '.avif',
  'image/heic': '.heic',
  'image/heif': '.heic',
  'image/bmp': '.bmp',
  'image/tiff': '.tiff',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/webm': '.webm',
  'video/x-matroska': '.mkv',
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/aac': '.aac',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
  'audio/flac': '.flac',
  'audio/ogg': '.ogg',
};

/// 把标题末尾的媒体后缀剥掉。
///
/// 有的平台标题就是文件名 —— 抖音这条实测是
/// `【8KHDR素材】…挪威冬日高画.mp4`。下载时落盘名是"标题 + 按地址猜的后缀",
/// 不剥的话会拼成 `…高画mp4.mp4`(实测:文件名里那个重复的 mp4 就是这么来的)。
///
/// 只认自己认得的那些后缀(见 [_extKind] 加几个常见的),别的 `.` 一律不动 ——
/// 标题里带点号太常见了(`1.2 万人点赞`),乱剥会把标题截掉一段。
String stripMediaExtension(String title) {
  final dot = title.lastIndexOf('.');
  if (dot <= 0 || dot == title.length - 1) return title;
  final ext = title.substring(dot + 1).toLowerCase();
  if (ext.length > 5 || !_extKind.containsKey(ext)) return title;
  return title.substring(0, dot);
}

/// 剥掉话题标签。`#冬日 #旅行` → 空,`原神#蒙德` → `原神 蒙德`。
///
/// 话题标签是给平台搜索用的,落进文件名只是白占字节 —— 而字节正是文件名最紧的
/// 资源(见 [safeFileName] 的上限)。字符集取到 64 字节那种 CJK 扩展区,是因为
/// 标签里常混着生僻字和 emoji 变体。
final RegExp _kHashtag = RegExp(r'#[^\s#]{0,32}', unicode: true);

/// emoji 与它们的装饰字符(变体选择符、零宽连接符、肤色修饰符、区域指示符)。
/// 这些在文件名里既不可读又占 3~4 字节,统一清掉。
final RegExp _kEmoji = RegExp(
  '['
  '\u{1F000}-\u{1FAFF}'
  '\u{2600}-\u{27BF}'
  '\u{FE00}-\u{FE0F}'
  '\u{200B}-\u{200D}'
  '\u{20E3}'
  '\u{1F1E6}-\u{1F1FF}'
  ']',
  unicode: true,
);

/// 同一个标点连打三下以上收成一个(`!!!` → `!`)。只收同一字符的连打:
/// `!?` 这种交替是用户真打出来的语气,动了就是改标题。
final RegExp _kPunctRun = RegExp(r'([!！?？~～。，,、])\1{2,}');

/// 压缩标题,让它更短但仍然认得出来是谁。
///
/// 四件事,按这个顺序做:剥话题标签、清 emoji 与非可读控制字符、收标点连打、
/// 折叠空白。**不动文字本身** —— 中文一个字 3 字节,是最贵的那部分,但它正是
/// 用户在相册里认文件的依据,再长也留着(截断交给 [safeFileName])。
String shortenTitle(String title) {
  return title
      .replaceAll(_kHashtag, ' ')
      .replaceAll(_kEmoji, '')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
      // Dart 的 replaceAll 不认 `$1` 这种反向引用(会原样打出来),得走 mapped。
      .replaceAllMapped(_kPunctRun, (m) => m.group(1)!)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// 字符串按 UTF-8 算多少字节。文件名上限是字节数,不是字符数。
int _utf8Len(String value) => utf8.encode(value).length;

/// 把解析出来的标题变成能落盘的文件名。
///
/// 保留中文(用户要靠它认文件),只清掉文件系统不接受的字符和控制字符。
///
/// **按字节截断,不按字符** —— 这里踩过坑:DownloadManager 限的是字节数,
/// 中文一个字 3 字节,而一个 52 字的标题就是 126 字节。当时按字符截到 60,
/// 结果系统从尾部继续砍,正好把 `.mp4` 扩展名切掉,存出来是个没有扩展名的文件
/// (实测:vivo + Android 17 上 130 字节的路径被截到 81 字节,扩展名没了)。
///
/// 66 字节 ≈ 22 个汉字,离已知会被截断的 81 字节还有余量。
///
/// [ext] 和 [index] 是**这次要拼在后面的后缀和序号**:上限量的是整个文件名,而
/// 调用方是在这个返回值后面再拼 `.mp4` 和 `_2` 的。不先扣掉的话,66 的上限形同虚设
/// (66 字节的标题 + `.mp4` 就是 70,离 81 那个已知会被砍的点只剩 11 字节余量)。
/// [ext] 传的是**候选后缀里最长的那个**:真实后缀要等下载器嗅探文件头才知道,
/// 现在多扣几字节,好过下载完发现总长超了没得改。
///
/// [index] 大于 0 时这里会**把它拼在末尾**(`标题_2`)并把它的字节算进上限 ——
/// 序号是名字的一部分,截断必须把它一起算,但它是"第几张"而不是标题里的话,
/// 不该被截掉。
String safeFileName(
  String raw, {
  String ext = '',
  int index = 0,
  String fallback = '即存媒体',
  int maxBytes = 66,
}) {
  final rawCleaned = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim();
  // 先剥话题标签、清 emoji,再清非法字符 —— 顺序反了的话 `#` 已被换成 `_`,
  // 标签就剥不掉了。
  //
  // 只有压出来还有点东西才用:整个标题都是 emoji 时会被清成空串,那种情况宁可把
  // 它留着(`🎬🔥.mp4` 总比 `即存媒体.mp4` 认得出来),但一个字的残渣("警")也不如
  // 原名,所以门槛定在 2 字节。
  final stripped = shortenTitle(rawCleaned);
  final cleaned = (_utf8Len(stripped) >= 2 ? stripped : rawCleaned)
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      // 剥标签、清 emoji 都会留下连着好几个的下划线,收一收
      .replaceAll(RegExp(r'_{2,}'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final tail = index > 0 ? '_$index' : '';
  if (cleaned.isEmpty) return '$fallback$tail';

  // 后缀按 5 字节封顶:解析期猜出来的最长是 `.jpeg`,而 CDN 那种
  // `~tplv-tt-large.image` 会猜出 6 个字符的 `.image` —— 那是个错后缀,不值得为它
  // 多扣一个字节的标题。真按 6 字节存下来时,由 [_retag] 收口。
  final extBytes = math.min(utf8.encode(ext).length, _kMaxExtBytes);
  final suffix = extBytes + _indexBytes(index);
  final budget = maxBytes > suffix ? maxBytes - suffix : maxBytes;
  final bytes = utf8.encode(cleaned);
  if (bytes.length <= budget) return '$cleaned$tail';

  // 按字节切可能把一个多字节字符劈成两半,allowMalformed 会把残片换成 U+FFFD,
  // 再把它去掉 —— 否则文件名里会留一个乱码方块。
  final cut = utf8
      .decode(bytes.sublist(0, budget), allowMalformed: true)
      .replaceAll('\uFFFD', '')
      .trim();
  return cut.isEmpty ? '$fallback$tail' : '$cut$tail';
}

/// 解析期给后缀留的字节上限。见 [safeFileName] 里为什么封顶。
const int _kMaxExtBytes = 5;

/// 序号 `_12` 占几字节。0 号(不编号)不占。
int _indexBytes(int index) => index <= 0 ? 0 : '_$index'.length;

/// 一个文件名的字节上限。见 [safeFileName] 里那段实测说明。
const int _kMaxNameBytes = 66;

/// 把标题那段收到 `[maxBytes] - 后缀` 之内,返回截好的标题。
///
/// 收尾改后缀时用(真实后缀只有下载完才知道),保证"标题 + 后缀"永远不超上限。
/// 解析期已经按最长的候选后缀扣过一次,所以这里只有猜错后缀(比如猜 `.jpeg`
/// 真来 `.webm`,或者 CDN 那种 `.image` 猜不出真格式)时才会真截到东西。
String _fitStem(String stem, String ext, int maxBytes) {
  final budget = maxBytes - utf8.encode(ext).length;
  final bytes = utf8.encode(stem);
  if (bytes.length <= budget) return stem;
  // 按字节切可能把一个多字节字符劈成两半,allowMalformed 会把残片换成 U+FFFD,
  // 再把它去掉 —— 否则文件名里会留一个乱码方块。
  return utf8
      .decode(bytes.sublist(0, budget), allowMalformed: true)
      .replaceAll('\uFFFD', '')
      .trim();
}
