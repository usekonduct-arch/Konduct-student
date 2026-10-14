# Konduct apps (Flutter)

One codebase, two apps (SRS 3.1):

| Flavor | App id | Entry | Look |
| --- | --- | --- | --- |
| `rider` | `com.konduct.rider` | `lib/main_rider.dart` | light "paper" |
| `driver` | `com.konduct.driver` | `lib/main_driver.dart` | dark, glanceable |

```
flutter run --flavor rider  -t lib/main_rider.dart
flutter run --flavor driver -t lib/main_driver.dart
flutter test
```

Use the real SDK at `C:\flutter\src\flutter\bin\flutter.bat` (the one on PATH is a stub).

## Connecting Firebase (FlutterFire)

Each flavor is its own Firebase Android app, so configure twice (needs `dart pub global activate flutterfire_cli`
and a Firebase CLI login that can see the project):

```
flutterfire configure --project=konduct-10ffb --platforms=android --android-package-name=com.konduct.rider  --out=lib/firebase/options_rider.dart  --android-out=android/app/src/rider/google-services.json  --yes
flutterfire configure --project=konduct-10ffb --platforms=android --android-package-name=com.konduct.driver --out=lib/firebase/options_driver.dart --android-out=android/app/src/driver/google-services.json --yes
```

These overwrite the two placeholder files in `lib/firebase/`; `firebase_options.dart` already picks them up.

## Demo mode

Until `lib/firebase/firebase_options.dart` has real values, the apps run on `DemoAuthRepository`:
SMS code `123456`, student ID `DUP123` plays a duplicate, and in the driver app any number ending
`0000` plays a driver no agent has onboarded. `--dart-define=KONDUCT_DEMO=true` forces demo mode later.

## Auth flow

Rider: welcome → phone → SMS code → name + student ID → PIN → ready.
Driver: welcome → phone → SMS code → matched to the agent's record → PIN → ready.

The screen is chosen from the Firebase ID token's custom claims (`role`, `pin`, `status`, `name`),
which only the backend sets (`konduct-backend`), so a relaunch needs no network call.

- `lib/auth/`: repository interface, Firebase + demo implementations, controller, gate, screens
- `lib/ui/kit.dart`: Pressable, KButton, Keypad, Shake, CodeSlots, PinDots, KMark
- `lib/ui/scene/`: the korope bus, students and campus, ported from the landing page SVG
- `lib/theme/tokens.dart`: palette and type, shared with the landing page

iOS flavors (schemes) are not set up yet; Android is the pilot target (SRS 2.3).
