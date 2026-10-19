import 'package:drift/drift.dart';
import 'package:flutter_softlib/app/database/database.dart';

part 'download_task_table.g.dart';

class DownloadTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get appId => text().unique()();

  TextColumn get taskId => text().unique()();

  TextColumn get appName => text()();

  TextColumn get appSize => text()();

  TextColumn get appIcon => text()();

  DateTimeColumn get createTime => dateTime().withDefault(currentDateAndTime)();
}

@DriftAccessor(tables: [DownloadTasks])
class DownloadTaskDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadTaskDaoMixin {
  DownloadTaskDao(super.db);

  /// 添加/覆盖下载任务记录
  /// ★ 必须 upsert：appId 与 taskId 都是 unique，同一个软件重复下载时
  ///   纯 insert 会抛 UNIQUE constraint failed，异常会中断调用方流程
  ///   （下载已开始，但进度轮询没启动 → 底部永远不显示进度条）。
  Future<int> setDownloadTask({
    required String taskId,
    required String appId,
    required String appName,
    required String appSize,
    required String appIcon,
  }) async {
    // 先清掉该 appId 与同 taskId 的旧记录，避免唯一约束冲突
    await (delete(downloadTasks)
          ..where((tbl) => tbl.appId.equals(appId) | tbl.taskId.equals(taskId)))
        .go();
    return into(downloadTasks).insert(
      DownloadTasksCompanion.insert(
        appId: appId,
        taskId: taskId,
        appName: appName,
        appSize: appSize,
        appIcon: appIcon,
      ),
    );
  }

  ///更新数据
  Future<int> updateDownloadTask({
    required String taskId,
    required String appId,
    required String appName,
    required String appSize,
    required String appIcon,
  }) async {
    return (update(
      downloadTasks,
    )..where((tbl) => tbl.appId.equals(appId))).write(
      DownloadTasksCompanion(
        taskId: Value(taskId),
        appName: Value(appName),
        appSize: Value(appSize),
        appIcon: Value(appIcon),
      ),
    );
  }

  ///删除数据
  Future<int> deleteDownloadTask(String appId) async {
    return (delete(
      downloadTasks,
    )..where((tbl) => tbl.appId.equals(appId))).go();
  }

  ///查询所有下载任务
  Future<List<DownloadTask>> queryAllDownloadTasks() async {
    final query = select(downloadTasks);
    final result = await query.get();
    return result;
  }

  ///根据appId查询下载任务,返回任务id
  Future<String?> queryDownloadTaskByAppId(String appId) async {
    final query = select(downloadTasks)
      ..where((tbl) => tbl.appId.equals(appId));
    final result = await query.get();
    if (result.isNotEmpty) {
      return result.first.taskId;
    }
    return null;
  }

  ///根据taskId查询下载任务
  Future<DownloadTask?> queryDownloadTaskByTaskId(String taskId) async {
    final query = select(downloadTasks)
      ..where((tbl) => tbl.taskId.equals(taskId));
    final result = await query.get();
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
