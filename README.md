# GradeX

GradeX is an academic performance tracker and timetable manager built for Nigerian university students. It helps students track their CGPA, manage course schedules, and stay on top of academic deadlines through real-time notifications and reminders.

## What GradeX Does

- **Grade & CGPA Tracking** — Students log courses, units, and grades; the app computes CGPA and per-semester GPA.
- **Timetable Management** — Weekly class schedules with reminders.
- **Announcements** — Course-level and school-wide announcements pushed to students, with per-course mute support.
- **Notifications** — In-app notification center plus push notifications (FCM) for reminders, announcements, and a daily morning digest.
- **Web Access** — A hosted web version (Firebase Hosting) with an APK download for Android users who land on the web app.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile/Web client | Flutter |
| State management | Provider |
| Backend API | Node.js / Express |
| Backend hosting | Render (free tier) |
| Primary database | MongoDB |
| Real-time / push | Firebase (Firestore + FCM) |
| Web hosting | Firebase Hosting |
| Local persistence | SharedPreferences |

## Architecture Notes

- **Notification system**: `NotificationStore` (SharedPreferences-backed) drives the in-app `NotificationsScreen`. `NotificationRouter` is the single source of truth for routing — used for in-app taps, FCM background taps, and cold-start taps alike. Don't add ad-hoc navigation logic outside of it.
- **Navigation from outside widget context**: Use `NavigationService` (`GlobalKey<NavigatorState>`) rather than passing `BuildContext` around for FCM-triggered navigation.
- **Tab routing**: `MainShell` accepts an `initialIndex` to land on the correct tab when opened from a notification.
- **State access pattern**: Use `context.watch` inside `build()`, and `context.read` in callbacks/methods outside the widget tree. Mixing these up is a common source of bugs — stick to this convention.
- **Announcements persistence**: Dismissed/cleared announcement cards must stay dismissed after a backend refresh. This is handled client-side via a `_dismissedIds` set — do not rely on the backend to track per-student dismissal state for this feature.
- **Cron jobs on Render free tier**: Render free tier spins down on inactivity, so scheduled jobs (like the morning digest) are triggered externally via cron-job.org using a two-step wake-up-ping + authenticated POST to `/api/admin/trigger-morning-digest`, rather than relying on an in-process scheduler alone.

## Design System

GradeX follows a strict, consistent design language — don't introduce new colors or one-off styles without discussion:

- **Primary brand color**: `#1565C0` (blue), used in a gradient with `#0D47A1` and `#1E88E5`.
- **AppBar**: Gradient header with rounded bottom corners, `SafeArea(bottom: false)`.
- **Dark mode**: Always verify text color explicitly — hardcoded black text on dark backgrounds is a recurring bug. Use theme-aware colors (see `ThemeNotifier` / `context.watch<ThemeNotifier>().isDarkMode`) everywhere, never hardcoded `Colors.black`.

## Web-Specific Behavior

Some features are web-only and gated with `kIsWeb` (e.g. the APK download button on the home screen). When adding web-only UI, follow this pattern rather than creating separate screens per platform.

## Known Gotchas

- **flutter_local_notifications + zonedSchedule**: On some Android OEM skins (confirmed on Xiaomi HyperOS and Samsung), alarms fire and dispatch at the AlarmManager level but produce no visible notification. This is an open issue — if you're debugging notification delivery, check OEM-specific battery/notification restrictions before assuming it's a code bug.
- **Duplicate notifications**: `NotificationService.init()` must only run once per app lifecycle — guarded with a `static bool _initialized` flag. Don't call `init()` speculatively in multiple places.
- **APK build errors**: An incomplete Android SDK Platform 36 install can cause an `android:attr/lStar not found` error. A JVM OOM crash during build can be fixed by reducing Gradle's `jvmargs` heap size in `gradle.properties`.

## Contributing

- Match the existing three-color design system and dark-mode handling described above.
- Route all in-app and push notification navigation through `NotificationRouter` / `NavigationService` — don't bypass it.
- Test dark mode explicitly for any new screen or widget; it's the most common regression.
- If your change touches the backend, confirm CORS origins and any Render free-tier cold-start implications (e.g. first request after inactivity takes 30–50s).

## License

_Add license information here._