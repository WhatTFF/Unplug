import 'dart:developer' show log;
import 'package:usage_stats/usage_stats.dart';
import 'storage_service.dart';

/// Reads foreground usage from Android's UsageStats API.
///
/// This class is display-only. It powers the dashboard numbers and nothing
/// else — enforcement lives entirely in the native AccessibilityService,
/// which reads the same limits straight out of SharedPreferences and acts on
/// them without any Dart involvement.
///
/// This distinction used to be blurred: a Dart Timer polled limits here and
/// fired a "force close" MethodChannel call when a group was over budget. That
/// path could not do its job. It redirected to the launcher without checking
/// which app was in the foreground, so a stale timer firing while the user was
/// reading email would throw them to the home screen. It also never ran in
/// practice — every block relaunches Dart with FLAG_ACTIVITY_CLEAR_TASK, which
/// destroys the isolate and restarts the timer before it could reach five
/// minutes. The result was a mechanism that could only misfire, and silently
/// did nothing otherwise.
///
/// ─── One reading, not the first bucket ────────────────────────────────────
///
/// The API returns a *list of buckets*, not one total per package. Asking for
/// the range since the reset hour and taking the first entry per package —
/// which is what this did — therefore reported the oldest bucket and ignored
/// every later one.
///
/// That is why Refresh on the dashboard could look stuck. The first bucket for a
/// package is a slice that has already closed, so its `totalTimeInForeground`
/// never moves again for the rest of the day: the tile said "18m left" at noon
/// and the exact same thing at midnight, while the native limiter — which sums
/// every bucket, see `groupUsageMinutes` in UsageAccessibilityService — had long
/// since blocked the group. The dashboard and the limiter were not disagreeing
/// about the limit; they were reading two different numbers and calling both
/// "usage today".
///
/// [UsageStats.queryAndAggregateUsageStats] is the same query with the summing
/// done by the platform, so this now agrees with the limiter by construction
/// rather than by two implementations happening to match. It is also one channel
/// call per group instead of one per package.
///
/// It still cannot see the app that is in the foreground *right now* — Android
/// commits that interval only once it closes. The dashboard is only ever read
/// while Unplug itself is in front, so the restricted app being measured is
/// always backgrounded and already committed. The in-flight estimate the limiter
/// needs is therefore not needed here; if this ever starts reporting from a
/// foreground service, it will be.
class UsageTracker {
  static final UsageTracker _instance = UsageTracker._internal();
  factory UsageTracker() => _instance;
  UsageTracker._internal();

  /// Start of the current usage day — midnight of the configured reset hour.
  DateTime _dayStart() {
    final h = StorageService().resetHour;
    final now = DateTime.now();
    return now.hour < h
        ? DateTime(now.year, now.month, now.day - 1, h)
        : DateTime(now.year, now.month, now.day, h);
  }

  /// Every package's foreground time since the reset hour, in milliseconds as
  /// strings — the shape the plugin hands back.
  Future<Map<String, UsageInfo>> _today() async {
    final startDate = _dayStart();
    final endDate = DateTime.now();
    log('UsageTracker: start=${startDate.toIso8601String()} '
        'end=${endDate.toIso8601String()}');
    return UsageStats.queryAndAggregateUsageStats(startDate, endDate);
  }

  /// Milliseconds-as-string to whole minutes, tolerating a missing or
  /// unparseable value rather than throwing the dashboard away over one entry.
  int _toMinutes(String? totalTimeInForeground) =>
      (int.tryParse(totalTimeInForeground ?? '') ?? 0) ~/ 60000;

  /// Returns usage time in minutes for a specific package today (reset hour
  /// configurable).
  Future<int> getUsageTime(String packageName) async {
    final stats = await _today();
    return _toMinutes(stats[packageName.trim()]?.totalTimeInForeground);
  }

  /// Returns cumulative usage for a group in minutes.
  Future<int> getGroupUsage(List<String> packageNames) async {
    final stats = await _today();
    var total = 0;
    for (final pkg in packageNames) {
      total += _toMinutes(stats[pkg.trim()]?.totalTimeInForeground);
    }
    return total;
  }
}
