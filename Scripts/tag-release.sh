#!/bin/bash
# Commit source changes first, then publish an increasing version to the personal fork.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$#" != 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'Usage: Scripts/tag-release.sh 1.2.1' >&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo 'Commit source changes before making a release.' >&2
    exit 1
fi
branch=$(git symbolic-ref --quiet --short HEAD)
case "$(git remote get-url --push origin)" in
    https://github.com/perhorst1234/rain_app|https://github.com/perhorst1234/rain_app.git|git@github.com:perhorst1234/rain_app.git) ;;
    *) echo 'Origin must point to the personal GitHub fork.' >&2; exit 1 ;;
esac
if [[ "$(gh repo view --json nameWithOwner --jq .nameWithOwner)" != perhorst1234/rain_app ]]; then
    echo 'Release destination must be perhorst1234/rain_app.' >&2
    exit 1
fi
git show-ref --verify --quiet "refs/tags/v$1" && { echo 'Version tag exists.' >&2; exit 1; }
python3 - "$1" <<'PY'
from pathlib import Path
import plistlib, re, sys
p = Path('RainBar/Info.plist')
data = plistlib.loads(p.read_bytes())
version = sys.argv[1]
parts = lambda v: tuple(map(int, v.split('.')))
if parts(version) <= parts(data['CFBundleShortVersionString']):
    raise SystemExit('Version must increase.')
build = str(int(data['CFBundleVersion']) + 1)
data.update(CFBundleShortVersionString=version, CFBundleVersion=build)
p.write_bytes(plistlib.dumps(data, sort_keys=False))
p = Path('RainBar.xcodeproj/project.pbxproj')
s = re.sub(r'CURRENT_PROJECT_VERSION = \d+;', f'CURRENT_PROJECT_VERSION = {build};', p.read_text())
s = re.sub(r'MARKETING_VERSION = [\d.]+;', f'MARKETING_VERSION = {version};', s)
p.write_text(s)
PY
git add RainBar/Info.plist RainBar.xcodeproj/project.pbxproj
git commit -m "Release $1"
git tag "v$1"
git push --atomic origin "$branch" "v$1"
