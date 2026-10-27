import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unplug/services/storage_service.dart';
import 'package:unplug/services/usage_tracker.dart';

/// The dashboard's reading of "usage today".
///
/// The bug this guards against was in the shape of the answer, not in the
/// arithmetic: the plugin hands back a *list of buckets* per package, and the
/// old code took the first entry for a package and returned only that bucket.
/// The first bucket is a slice that has already closed, so the number stopped
/// moving for the rest of the day — while the native limiter, which sums every
/// bucket, had long since blocked the group. Hence a dashboard that said "18m
/// left" over an app that would not open.
///
/// That can only be fixed by asking the platform for the aggregate, so the
/// tests here pin the call as well as the totals.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('usage_stats');
  final List<String> calls = <String>[];
  Map<String, Map<String, String>> stats = {};

  Map<String, String> entry(int foregroundMs) => {
        'totalTimeInForeground': foregroundMs.toString(),
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
    calls.clear();
    stats = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method != 'queryAndAggregateUsageStats') return null;
      return stats;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a group totals every app in it, in whole minutes', () async {
    stats = {
      'com.instagram.android': entry(12 * 60 * 1000 + 59000),
      'com.snapchat.android': entry(5 * 60 * 1000),
    };

    expect(
      await UsageTracker().getGroupUsage(
        const ['com.instagram.android', 'com.snapchat.android'],
      ),
      equals(17),
    );
  });

  // A package with no usage today is simply absent from the response; treating
  // that as an error would blank the whole dashboard over one unused app.
  test('a package with no usage today counts as zero', () async {
    stats = {'com.instagram.android': entry(60 * 1000)};

    expect(
      await UsageTracker().getGroupUsage(
        const ['com.instagram.android', 'com.facebook.katana'],
      ),
      equals(1),
    );
    expect(await UsageTracker().getUsageTime('com.facebook.katana'), equals(0));
  });

  test('a single package reports its own minutes', () async {
    stats = {
      'com.instagram.android': entry(9 * 60 * 1000),
      'com.snapchat.android': entry(4 * 60 * 1000),
    };

    expect(
      await UsageTracker().getUsageTime('com.snapchat.android'),
      equals(4),
    );
  });

  // One aggregated query per call, rather than one per package: the per-package
  // path was the one that could return a single bucket.
  test('the platform is asked for the aggregate, once', () async {
    stats = {'com.instagram.android': entry(60 * 1000)};

    await UsageTracker()
        .getGroupUsage(const ['com.instagram.android', 'com.snapchat.android']);

    expect(calls, equals(['queryAndAggregateUsageStats']));
  });
}
