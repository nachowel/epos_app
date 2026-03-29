import 'shift.dart';

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.todaySalesTotalMinor,
    required this.activeShift,
    required this.openOrderCount,
    required this.pendingSyncCount,
    required this.failedSyncCount,
  });

  final int todaySalesTotalMinor;
  final Shift? activeShift;
  final int openOrderCount;
  final int pendingSyncCount;
  final int failedSyncCount;
}
