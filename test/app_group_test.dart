import 'package:flutter_test/flutter_test.dart';
import 'package:unplug/models/app_group.dart';

void main() {
  group('BannedFeature & AppGroup tests', () {
    test('BannedFeature serialization & deserialization', () {
      final feature = BannedFeature(
        id: 'yt_shorts',
        name: 'YouTube Shorts',
        packageName: 'com.google.android.youtube',
        isEnabled: true,
        contentKeywords: ['shorts', 'reel_player'],
        activityPattern: '.*shorts.*',
      );

      final json = feature.toJson();
      expect(json['id'], equals('yt_shorts'));
      expect(json['name'], equals('YouTube Shorts'));
      expect(json['packageName'], equals('com.google.android.youtube'));
      expect(json['isEnabled'], equals(true));
      expect(json['contentKeywords'], contains('shorts'));

      final restored = BannedFeature.fromJson(json);
      expect(restored.id, equals('yt_shorts'));
      expect(restored.name, equals('YouTube Shorts'));
      expect(restored.packageName, equals('com.google.android.youtube'));
      expect(restored.isEnabled, isTrue);
      expect(restored.contentKeywords, equals(['shorts', 'reel_player']));
      expect(restored.activityPattern, equals('.*shorts.*'));
    });

    test('AppGroup with bannedFeatures serialization', () {
      final group = AppGroup(
        name: 'Entertainment',
        packageNames: ['com.google.android.youtube'],
        timeLimitMinutes: 60,
        bannedFeatures: [
          BannedFeature(
            id: 'yt_shorts',
            name: 'YouTube Shorts',
            packageName: 'com.google.android.youtube',
            contentKeywords: ['shorts'],
          ),
        ],
      );

      final json = group.toJson();
      expect(json['bannedFeatures'], isNotNull);
      final restored = AppGroup.fromJson(json);
      expect(restored.name, equals('Entertainment'));
      expect(restored.bannedFeatures.length, equals(1));
      expect(restored.bannedFeatures.first.name, equals('YouTube Shorts'));
    });

    test('interstitials default to off and survive a round trip', () {
      final group = AppGroup(
        name: 'Social Media',
        packageNames: ['com.instagram.android'],
        timeLimitMinutes: 30,
      );
      // Off by default: a newly created group must not inherit friction the
      // user never asked for.
      expect(group.breakReminderEnabled, isFalse);
      expect(group.openGateEnabled, isFalse);
      expect(group.breakReminderMinutes, equals(10));

      group.breakReminderEnabled = true;
      group.openGateEnabled = true;
      group.breakReminderMinutes = 25;
      final restored = AppGroup.fromJson(group.toJson());
      expect(restored.breakReminderEnabled, isTrue);
      expect(restored.openGateEnabled, isTrue);
      expect(restored.breakReminderMinutes, equals(25));
    });

    test('time alerts default off and preserve selected thresholds', () {
      final group = AppGroup(
        name: 'Social',
        packageNames: const [],
        timeLimitMinutes: 60,
      );
      expect(group.timeAlertEnabled, isFalse);
      expect(group.timeAlertMinutes, isEmpty);
      expect(group.timeAlertPercentages, isEmpty);

      group.timeAlertEnabled = true;
      group.timeAlertMinutes = [15, 5];
      group.timeAlertPercentages = [50];
      final restored = AppGroup.fromJson(group.toJson());
      expect(restored.timeAlertEnabled, isTrue);
      expect(restored.timeAlertMinutes, [5, 15]);
      expect(restored.timeAlertPercentages, [50]);
    });

    test('time alert thresholds fire when crossed, not on every check', () {
      final group = AppGroup(
        name: 'Social',
        packageNames: const [],
        timeLimitMinutes: 60,
        timeAlertEnabled: true,
        timeAlertMinutes: [15],
        timeAlertPercentages: [50],
      );
      expect(group.crossedTimeAlerts(
        previousUsedMinutes: 20,
        currentUsedMinutes: 46,
        effectiveLimitMinutes: 60,
      ), ['15 minutes left', '50% of time left']);
      expect(group.crossedTimeAlerts(
        previousUsedMinutes: 46,
        currentUsedMinutes: 47,
        effectiveLimitMinutes: 60,
      ), isEmpty);
    });

    test('a group stored before these fields loads as off', () {
      // Exactly the shape written by an older build. Loading must not throw
      // and must not switch anything on — the Kotlin side reads the same keys
      // with optBoolean, so the two agree on what an old payload means.
      final restored = AppGroup.fromJson({
        'name': 'Entertainment',
        'packageNames': ['com.google.android.youtube'],
        'timeLimitMinutes': 60,
      });
      expect(restored.breakReminderEnabled, isFalse);
      expect(restored.openGateEnabled, isFalse);
      expect(restored.breakReminderMinutes, equals(10));
      expect(restored.timeAlertEnabled, isFalse);
      expect(restored.timeAlertMinutes, isEmpty);
      expect(restored.timeAlertPercentages, isEmpty);
    });

    test('breakReminderMinutes is clamped to a sane range', () {
      // A stored or hand-edited value must not be able to make the reminder
      // fire instantly or effectively never.
      expect(
        AppGroup(
          name: 'g',
          packageNames: const [],
          timeLimitMinutes: 30,
          breakReminderMinutes: 0,
        ).breakReminderMinutes,
        equals(1),
      );
      expect(
        AppGroup(
          name: 'g',
          packageNames: const [],
          timeLimitMinutes: 30,
          breakReminderMinutes: 99999,
        ).breakReminderMinutes,
        equals(60),
      );
    });
  });
}
