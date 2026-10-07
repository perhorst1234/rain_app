#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' RainBar/Info.plist)
if [[ -n "${RELEASE_TAG:-}" && "$RELEASE_TAG" != "v$version" ]]; then
    echo "Release tag does not match app version" >&2
    exit 1
fi
build_dir="${RAINBAR_BUILD_DIR:-$PWD/build}"
mkdir -p "$build_dir"
xcodebuild -project RainBar.xcodeproj -scheme RainBar -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$build_dir" \
    ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build > "$build_dir/build.log" 2>&1 || {
    tail -100 "$build_dir/build.log" >&2
    exit 1
}
swiftc -parse-as-library RainBar/RainService.swift RainBar/WeatherService.swift \
    Tests/ForecastChecks.swift -o "$build_dir/forecast-checks"
"$build_dir/forecast-checks" --offline
stage=$(mktemp -d "$build_dir/stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$build_dir/Build/Products/Release/RainBar.app" "$stage/RainBar.app"
app="$stage/RainBar.app"
test -d "$app/Contents/Frameworks/Sparkle.framework"
lipo "$app/Contents/MacOS/RainBar" -verify_arch x86_64 arm64
strip -S "$app/Contents/MacOS/RainBar"
codesign --force --sign - --preserve-metadata=identifier,entitlements "$app"
codesign --verify --deep --strict --all-architectures "$app"
archive_dir="$build_dir/release-v$version"
if [[ -e "$archive_dir" ]]; then
    echo "Release directory already exists: $archive_dir" >&2
    exit 1
fi
mkdir -p "$archive_dir"
archive="$archive_dir/RainBar-NL-v$version-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
tools="$build_dir/SourcePackages/artifacts/sparkle/Sparkle/bin"
key_args=(--account rainbar-perhorst1234)
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then key_args=(--ed-key-file "$SPARKLE_KEY_FILE"); fi
"$tools/generate_appcast" "${key_args[@]}" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/perhorst1234/rain_app/releases/download/v$version/" \
    --link 'https://github.com/perhorst1234/rain_app/releases' "$archive_dir"
"$tools/sign_update" "${key_args[@]}" --verify "$archive_dir/appcast.xml"
signature=$(python3 - "$archive_dir/appcast.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
feed = ET.parse(sys.argv[1])
print(feed.find('./channel/item/enclosure').attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'])
PY
)
"$tools/sign_update" "${key_args[@]}" --verify "$archive" "$signature"
swiftc -parse-as-library Tests/ReleaseSignatureChecks.swift -o "$build_dir/release-signature-checks"
"$build_dir/release-signature-checks" "$archive" "$archive_dir/appcast.xml" "$app/Contents/Info.plist"
(cd "$archive_dir" && shasum -a 256 "RainBar-NL-v$version-universal.zip" appcast.xml > SHA256SUMS.txt)
printf 'Release ready: %s\n' "$archive_dir"
