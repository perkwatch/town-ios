# Push notifications — WIRING STUB ONLY

Status: **STUB** (2026-11-07, All-Apps Program build visit #2)

- Plugin installed: `@capacitor/push-notifications` (^6.0.0, matching Capacitor ^6.1.2).
- NO FCM (Android) configuration: no `google-services.json`, no Firebase project.
- NO APNs (iOS) configuration: no push entitlement, no APNs key/certificate.
- NO server changes, NO live registration code paths: no `PushNotifications.register()`,
  no listener code, and no token handling exists in `www/` or the native projects
  beyond the plugin's own generated registration that Capacitor sync performs.
- Town HAS platform accounts (real accounts live on the shared platform), so this
  stub is the correct state until push is wired end-to-end in a future visit.
- To go live (future, Tyler-gated): create Firebase project + APNs key, add native
  config files, add registration code in the web app, and add a server endpoint to
  store tokens and send notifications. None of that is done here.
