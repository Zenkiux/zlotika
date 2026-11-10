# Zlotika

**Apsipirk Lenkijoje išmaniau.** A free, ad-free app that helps people from Lithuania decide whether a shopping trip to Poland is worth it.

- **Prices:** compare Polish and Lithuanian prices.
- **Leaflets:** read Biedronka, Kaufland and Lidl leaflets in the app.
- **Trip cost:** include fuel and see your real saving.
- **Shopping list:** shows each item's Polish name so you can find it on the shelf, and shows it to staff when needed.

Built with Flutter for iOS, Android, web and macOS. The code is under the MIT licence; the name and logo are reserved (see `TRADEMARKS.md`). Contributions are welcome (see `CONTRIBUTING.md`). Deals and leaflets come from the companion collector repository, [zlotika-data](https://github.com/Zenkiux/zlotika-data).

---

## Developer notes (maintainer's setup)

One codebase for every platform. The UI is in Lithuanian and English. Polish appears only as original product names and on the "show to staff" screen.

## Where things live (all on the ADATA SSD)

The ADATA SSD is formatted exFAT, which breaks Xcode code signing and symlinks. So the toolchain and this app live in an **APFS disk image stored on the SSD**:

- Image: `/Volumes/ADATA/Zlotika/ZlotikaDev.sparsebundle`. It grows as needed, up to 150 GB.
- Mounted at: `/Volumes/ZlotikaDev`
  - `toolchain/flutter`: Flutter 3.47.9 / Dart 3.13.7
  - `toolchain/pub-cache`, `gradle`, `android-sdk`, `avd`: package caches and the Android tools (Android tools are installed later)
  - `zlotika/`: this app

After a restart, mount the image and load the environment:

```bash
hdiutil attach /Volumes/ADATA/Zlotika/ZlotikaDev.sparsebundle
source /Volumes/ZlotikaDev/toolchain/env.sh
cd /Volumes/ZlotikaDev/zlotika
```

## Run

| Target | Command |
|---|---|
| iPhone (cable or same Wi-Fi) | `flutter run -d <iPhone>`. On first run, open `ios/Runner.xcworkspace` in Xcode and choose your Team under Signing & Capabilities. |
| Web | `flutter run -d chrome`, or `flutter build web` and serve `build/web` |
| macOS | `flutter run -d macos` |
| Android | Needs the Android SDK installed into `toolchain/android-sdk` (planned next step) |

## Check

```bash
flutter analyze && flutter test
```

## Real data in this version

| Data | Source | Notes |
|---|---|---|
| EUR/PLN rate | NBP API Table A (live) | Cached on the phone and refreshed when the app is reopened |
| Product name by barcode | Open Food Facts (live) | ODbL licence, attribution shown |
| Trading Sundays and holidays | Polish law, stored in `lib/data/calendar.dart` | 2026–2027 |
| LT ↔ EN ↔ PL product names | `lib/data/dictionary.dart` | About 130 hand-checked terms |
| Distances | `lib/data/geo.dart` | Approximate. To be replaced by a precomputed OSRM matrix. |
| Shop and fuel prices | **Entered by the user** | No licensed free source exists yet (see `docs/PLAN.md`) |

## Structure

```
lib/core       theme (from logo), i18n (lt/en), app state + persistence, formatting
lib/data       towns & distances, Polish retail calendar, LT/EN/PL dictionary
lib/services   NBP rate, Open Food Facts lookup
lib/features   home, list (+ add, price sheet, staff screen), trip wizard, converter, scanner, more, onboarding
lib/widgets    shared UI pieces (buttons, panels, flag ribbon, Polish name tag, stepper)
test/          calendar, formatting, dictionary, basket and trip calculations
```
