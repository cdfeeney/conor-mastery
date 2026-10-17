# Family Controls entitlement request (copy-paste answers)

Why: app blocking (Screen Time) only works on TestFlight and App Store builds after Apple approves the
**Family Controls (Distribution)** entitlement. Development builds can use it without approval, but we have
no Mac to install development builds, so TestFlight is our only route to the phone.

**Who submits:** the Apple Developer **Account Holder**, signed in at
https://developer.apple.com/contact/request/family-controls-distribution

**Submit one request per bundle ID** (the form asks for one at a time):

| Target | Bundle ID |
|---|---|
| App | `com.conorfee.conormastery` |
| Screen Time monitor extension | `com.conorfee.conormastery.monitor` |

Before submitting, register both IDs under Certificates, Identifiers & Profiles → Identifiers, with the
**Family Controls** capability and the App Group `group.com.conorfee.conormastery` ticked.

## Answers

- **App name:** Conor Mastery
- **Who uses it:** individuals, on their own device (`AuthorizationCenter.requestAuthorization(for: .individual)`).
  It does not manage children's devices.
- **How the app uses Family Controls:**

> Conor Mastery is a personal habit tracker. The user picks distracting apps and websites with
> FamilyActivityPicker. The app then uses ManagedSettings to shield those apps (1) until the user has
> finished their morning routine, (2) during an evening wind-down window they set, and (3) during focus
> sessions they start. A DeviceActivityMonitor extension applies and lifts the shields at the scheduled
> times while the app is closed. The user can unlock early by spending points they earned in the app, and
> can turn blocking off in Settings at any time. No app-usage data leaves the device, and the app has no
> account, server or analytics.

- **Frameworks:** FamilyControls, ManagedSettings, DeviceActivity.

## After approval

Apple usually replies by email within a few days to a few weeks. When it arrives, tell Claude.
The next TestFlight build then has to regenerate its provisioning profiles so they include the
distribution entitlement.
