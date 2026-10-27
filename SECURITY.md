# Security Policy

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private advisory form:

> <https://github.com/WhatTFF/Unplug/security/advisories/new>

That creates a private thread only you and the maintainer can see, and it lets
a fix be prepared and released before the details are public.

If you cannot use GitHub, email **emin.by@outlook.com** with `Unplug security`
in the subject.

Please include what you can: the affected version (Settings shows it, or check
`VERSION`), the device and Android version, what you did, and what happened.
A proof of concept helps but is not required.

## What to expect

This is a one-person project, so these are intentions rather than a service
level:

- Acknowledgement within about 7 days.
- An assessment and a rough timeline within about 30 days.
- Credit in the release notes and the advisory, unless you ask not to be named.
- Please give 90 days before publishing details, or less if a fix ships sooner.

## In scope

Unplug asks for unusually powerful permissions, and those are the interesting
attack surface:

- **The update path** — `lib/services/update_checker.dart`, the download, and
  the handoff to Android's installer. A compromised update is the worst case
  here: it would run with the accessibility service already granted.
- **`UsageAccessibilityService`** — reading foreground app changes, drawing the
  lock screen, pressing Back. Anything that lets another app make it block the
  wrong thing, or stop blocking, without the user asking.
- **Local storage** — limits, bonuses, and settings in shared preferences.
  Anything that lets another app on the device tamper with them.
- **Data leaving the device.** There should be exactly one outbound request in
  the whole app, the version check. Anything else is a finding.
- **The exported components** in `AndroidManifest.xml`.

## Out of scope

- Anything that requires a rooted device, an unlocked bootloader, or `adb` on a
  device the attacker already controls.
- Bypasses that need the user to deliberately disable the accessibility
  service, revoke permissions, or uninstall the app. Unplug cannot defend
  against the person holding the phone.
- The Google Play Protect "unknown app" warning. That is expected for any app
  without install history; the README explains it.
- Missing hardening that has no demonstrated impact.
- Reports produced only by an automated scanner, with no working path to
  abuse.

## Supported versions

Only the newest published release gets fixes. There are no backports to older
versions — the update path exists so people can move forward.
