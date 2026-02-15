# smart_saver

A new Flutter project.

## Local Notifications (free plan friendly)

The app is configured to use local notifications from a background service that listens to:
`/home/gas_sensor/level` in Firebase Realtime Database.

### What is configured

- Cloud push (FCM from Functions) is disabled: `kUseFirebaseCloudPush = false`
- Background service reads gas level directly from Realtime Database
- Alerts are shown via `flutter_local_notifications`
- Alert thresholds:
  - `warning`: from `6` to less than `50`
  - `danger`: `50` and above

### Test

1. Run app once and allow notification permission.
2. Keep internet on and close app (do not force stop).
3. Write a high value to `/home/gas_sensor/level` (e.g. `55` or `80`).
4. Local notification should appear on Android.
