#!/usr/bin/env bash
# Publish a new Android build that installed copies offer as an update.
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

git add pubspec.yaml
git commit -m "Release $tag" -m "$notes"
git push
gh release create "$tag" "$apk" --title "Zlotika $ver" --notes "$notes"
echo "✓ Published $tag — Android phones will offer the update."
