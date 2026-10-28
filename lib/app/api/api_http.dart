import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// ★ 1029：全 App 共用一个 HTTP 客户端
///
/// 之前 11 个 service 各自 `Dio(...)`，每个都自带一个 HttpClient →
/// 各自维护连接池 / TLS 会话。首页一次并发 5~6 个接口，就相当于
/// 同时做 5~6 次 TCP+TLS 握手（4G 下每次 100~200ms），
/// 切页、下拉刷新又要重来一遍。
///
/// 现在所有 Dio 共用同一个 IOHttpClientAdapter（即同一个 HttpClient），
/// 连接、TLS 会话、HTTP/2 的设置都能跨 service 复用：
///   · 首次访问只握手 1 次，之后所有接口走已建好的连接
///   · 保活时长放宽到 30s（默认 15s），来回切页不用重连
class ApiHttp {
  ApiHttp._();

  static final IOHttpClientAdapter adapter = IOHttpClientAdapter(
    createHttpClient: () {
      final c = HttpClient();
      // 同一个 host 最多并发几条连接（默认 6，图片多的时候容易排队）
      c.maxConnectionsPerHost = 12;
      // 空闲连接保留多久（默认 15s，切页回来多半已断开）
      c.idleTimeout = const Duration(seconds: 30);
      // 建连超时（DNS + TCP + TLS），默认 0 = 不限，卡住就一直等
      c.connectionTimeout = const Duration(seconds: 8);
      c.autoUncompress = true;
      return c;
    },
  );

  /// 给某个 Dio 挂上共用客户端
  static Dio attach(Dio dio) {
    dio.httpClientAdapter = adapter;
    return dio;
  }

  /// 造一个挂了共用客户端的 Dio
  static Dio create(BaseOptions opt) => attach(Dio(opt));
}
