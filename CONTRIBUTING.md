# Contributing to Unplug

Thanks for looking. Unplug is a one-person project, so the most useful things
you can do are, in order: **report a bug well**, **tell me what broke on your
device**, and **send a small, focused pull request**.

This file is short on ceremony and long on the one thing that actually bites
contributors: the native limiter. Read that section before touching Kotlin.

---

## Before you write code

Open an issue first, or comment on an existing one. Not to gatekeep — to avoid
you spending an evening on something that is already planned, already tried, or
deliberately not going to happen (see *What will not be merged* below).

Small fixes — a typo, a crash, an obviously wrong string — can go straight to a
pull request without an issue.

## What will not be merged

The README makes promises, and code that breaks them gets closed regardless of
quality:

- Accounts, sign-up, or any kind of login.
- Cloud sync, backup services, or a server of any kind.
- Analytics, telemetry, crash reporting SDKs, or "anonymous" usage stats.
- Advertising, tracking pixels, or anything from a data broker.
- Anything that reads screen content, keystrokes, or message bodies. The
  accessibility service exists to see *which app is in front*, nothing more.
- Sending the writing challenge, the limits, or the usage numbers anywhere.

The only network request in the app is the version check in
`lib/services/update_checker.dart`. A change that adds a second one is a
different app.

## Setting up

```bash
git clone https://github.com/WhatTFF/Unplug.git
cd Unplug
flutter pub get
./tool/gen_version.sh     # only needed after a version change
flutter build apk --release
```

Built and released against **Flutter 3.47.7**. The Android side needs Gradle
8.14+, AGP 8.11.1+, Kotlin 2.2.20, NDK 28.x, and minSdk is 24.

The version number lives in the `version:` line of `pubspec.yaml` and is
mirrored into `VERSION` and the generated `lib/generated/app_version.dart`.
Never edit `app_version.dart` by hand.

## Checks to run before opening a pull request

```bash
flutter analyze
flutter test
```

Both must be clean. Two tests in `test/version_test.dart` hit the live GitHub
Releases API unauthenticated and fail with **HTTP 403** once the 60-requests-
per-hour limit for your IP is used up. That is not caused by your change. If you
suspect it is, stash your work and run the suite again on a clean tree.

## The rule that matters: the native limiter needs a real device

Everything in `android/app/src/main/kotlin/com/egbytest/unplug/` has **no test
harness at all**. `flutter analyze` does not see it, `flutter test` does not
exercise it, and a diff that looks entirely reasonable can leave the app
blocking nothing.

This has already happened. Twice. v2.0.2 and v2.1.0 both shipped broken
enforcement from the same bug: a `Handler.postDelayed` call given seconds where
milliseconds were expected. A 17-minute deadline was armed at 1020 ms, which
became a self-rearming once-a-second loop running a synchronous usage query on
the very looper accessibility events arrive on. The app stopped blocking
anything. `flutter analyze` was clean, all 88 tests passed, and the diff looked
fine.

So, if your change touches `UsageAccessibilityService.kt`:

1. Install the built APK on a real device. Not an emulator, not a "it compiles".
2. Watch the log while you use it:

   ```bash
   adb logcat -s UsageService
   ```

3. For anything periodic or timed, **check the intervals, not just the
   messages**. The bug above printed "17m" in a message that arrived once a
   second. That mismatch was the entire bug, and it was visible in the first
   sixty lines of the log.
4. Say in the pull request what you did and what you saw. "Works on my Pixel 7
   on Android 14, blocked after the limit, log showed the deadline once per
   minute" is enough.

Mind the units of anything handed to an Android timing or sizing API.
`postDelayed` takes **milliseconds**. `setRepeating` takes **milliseconds**.
`WindowManager.LayoutParams` durations are **milliseconds**. They all accept
`Long`, so the wrong unit compiles silently and is wrong by a factor of a
thousand rather than by an error.

## Code style

- Follow the lints in `analysis_options.yaml`. `flutter analyze` is the style
  guide.
- Match the surrounding code. Comments explain *why*, not *what*.
- No new dependencies without discussing it in an issue first. Every package is
  a promise the app has to keep on someone else's phone, and several of the
  permissions in the manifest come from what those packages needed.
- Do not reformat files you are not changing. A pull request that is 90%
  whitespace will be sent back.

## Commits and pull requests

- Keep a pull request to one thing. Two unrelated fixes in one branch will be
  asked to split.
- Commit subjects are short and prefixed, matching the existing history:
  `fix:`, `chore:`, `docs:`, `release:`. The body explains why.
- **Do not bump the version.** The version, the tag, the README download
  section, and the release notes are one decision made at release time by the
  maintainer. A pull request that bumps `pubspec.yaml` will be asked to drop
  that commit.
- **Do not update the README for a release.** Same reason. Do update it if your
  change makes something the README says untrue.
- For anything visible in the UI, include a screenshot or a short recording.
- Expect review to take a while. It is one person, and anything touching
  enforcement gets read slowly on purpose.

## Security

Do not open a public issue for a security problem. Use the private advisory
form linked in [SECURITY.md](SECURITY.md).

## Licence of your contribution

Unplug is licensed under the **GNU General Public License, version 3.0 only**
(see [LICENSE](LICENSE)). There is no CLA to sign and no copyright assignment.

By opening a pull request you confirm that you wrote the change (or have the
right to submit it) and that you license it to this project under the same
GPL-3.0-only terms. If your employer owns your work, make sure they are fine
with that before you submit.

## Code of conduct

Participation is covered by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). The short
version: be decent, no contempt for the people this app is for, no medical
advice.
