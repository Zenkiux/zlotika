# Contributing to Zlotika

Thanks for helping Lithuanian shoppers save money. Zlotika is free, has no ads and needs no account, and it should stay that way.

## Ground rules
- **No fake data.** Never show invented prices, stock or discounts. When we don't know something, say so.
- **Keep it simple.** One clear question per screen, large text, plain words. Many users are older people.
- **App language:** Lithuanian first, English second. Polish appears only as original product names, so shoppers can match shelf labels.
- **Privacy:** no accounts, tracking or location by default. Data stays on the phone.

## Getting started
```bash
flutter pub get
flutter analyze && flutter test
flutter run            # iOS, Android, web or macOS
```
To sign iOS builds, put your own team in `ios/Flutter/Signing.xcconfig` (git-ignored):
```
DEVELOPMENT_TEAM = YOURTEAMID
```

## Where things are
- `lib/core`: theme (taken from the logo), translations (`i18n.dart`, LT and EN), state, formatting
- `lib/data`: towns and distances, Polish shop calendar, the LT/EN/PL product dictionary
- `lib/services`: NBP rate, Open Food Facts, deals and leaflets feed
- `lib/features`: one folder per screen

## Good first contributions
- Add words to `lib/data/dictionary.dart` (Lithuanian · English · Polish shelf name).
- Improve translations in `lib/core/i18n.dart`.
- Add a Lithuanian town to `lib/data/geo.dart`, with road distances.
- **Retailer data** is collected in the separate collector repository, **zlotika-data**. New chains belong there.

Please run `flutter analyze` and `flutter test` before opening a pull request.
