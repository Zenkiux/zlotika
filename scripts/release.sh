#!/usr/bin/env bash
# Publish a new build (Android APK + iPhone Ad Hoc) that installed copies offer as an update.
#
#   scripts/release.sh "What changed (LT)" [patch|minor|major|same]
#
# Bumps the build number in pubspec.yaml (and the version if asked), builds a
# signed APK, commits the bump and creates a GitHub release v<version>+<build>
# with the APK attached. The app checks the latest release and shows "Atnaujinti".
# iPhones are updated by cable: flutter build ios --release + devicectl install.
set -euo pipefail
cd "$(dirname "$0")/.."
source /Volumes/ZlotikaDev/toolchain/env.sh
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"

notes="${1:?Usage: scripts/release.sh \"release notes\" [patch|minor|major|same]}"
bump="${2:-patch}"

[ -f android/key.properties ] || { echo "android/key.properties missing (copy from /Volumes/ZlotikaDev/keys)"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "Commit your changes first."; exit 1; }

cur=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *//')
ver=${cur%+*}; build=${cur#*+}
IFS=. read -r maj min pat <<<"$ver"
case "$bump" in
  major) maj=$((maj + 1)); min=0; pat=0 ;;
  minor) min=$((min + 1)); pat=0 ;;
  patch) pat=$((pat + 1)) ;;
  same) ;;
  *) echo "bump must be patch, minor, major or same"; exit 1 ;;
esac
ver="$maj.$min.$pat"; build=$((build + 1)); tag="v$ver+$build"
sed -i '' -E "s/^version: .*/version: $ver+$build/" pubspec.yaml
echo "→ $tag"

flutter build apk --release --target-platform android-arm,android-arm64
apk="build/app/outputs/flutter-apk/zlotika-$ver.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$apk"

# iPhone Ad Hoc build: installs from a link on registered iPhones (scripts/add-iphone.sh).
TEAM=$(grep DEVELOPMENT_TEAM ios/Flutter/Signing.xcconfig | sed 's/.*= *//' | tr -d ' ')
mkdir -p build/ios-export
cat > build/ios-export/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>release-testing</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>compileBitcode</key><false/>
  <key>thinning</key><string>&lt;none&gt;</string>
</dict></plist>
PLIST
flutter build ipa --release --export-options-plist=build/ios-export/ExportOptions.plist
ipa="build/ios/ipa/zlotika-$ver.ipa"
cp build/ios/ipa/Zlotika.ipa "$ipa"
PAGES="https://zenkiux.github.io/zlotika-data/ios"
cat > build/ios-export/manifest.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>items</key><array><dict>
  <key>assets</key><array><dict><key>kind</key><string>software-package</string><key>url</key><string>$PAGES/zlotika.ipa</string></dict></array>
  <key>metadata</key><dict>
    <key>bundle-identifier</key><string>lt.zlotika.zlotika</string>
    <key>bundle-version</key><string>$ver</string>
    <key>kind</key><string>software</string>
    <key>title</key><string>Zlotika</string>
  </dict>
</dict></array></dict></plist>
PLIST

git add pubspec.yaml
git commit -m "Release $tag" -m "$notes"
git push
gh release create "$tag" "$apk" "$ipa" build/ios-export/manifest.plist --title "Zlotika $ver" --notes "$notes"
# Republish the data site so the iPhone install link serves this build.
gh workflow run translate.yml --repo Zenkiux/zlotika-data || echo "(start the zlotika-data translate workflow by hand)"
echo "✓ Published $tag — Android and iPhones will offer the update (iPhone link live in a few minutes)."
