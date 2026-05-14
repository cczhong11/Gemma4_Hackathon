#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <marketing-version> [build-version]" >&2
  exit 1
fi

marketing_version="$1"
build_version="${2:-$1}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

project_yml="$repo_root/ios/project.yml"
info_plist="$repo_root/ios/Gemma4App/Info.plist"
pbxproj="$repo_root/ios/Gemma4App.xcodeproj/project.pbxproj"

perl -0pi -e 's/MARKETING_VERSION: "[^"]+"/MARKETING_VERSION: "'"$marketing_version"'"/g; s/CURRENT_PROJECT_VERSION: "[^"]+"/CURRENT_PROJECT_VERSION: "'"$build_version"'"/g' "$project_yml"
perl -0pi -e 's#(<key>CFBundleShortVersionString</key>\s*<string>)[^<]+(</string>)#${1}'"$marketing_version"'${2}#g; s#(<key>CFBundleVersion</key>\s*<string>)[^<]+(</string>)#${1}'"$build_version"'${2}#g' "$info_plist"
perl -0pi -e 's/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = '"$marketing_version"';/g; s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = '"$build_version"';/g' "$pbxproj"

echo "Updated iOS app version fields:"
echo "  MARKETING_VERSION = $marketing_version"
echo "  CURRENT_PROJECT_VERSION = $build_version"
echo "  CFBundleShortVersionString = $marketing_version"
echo "  CFBundleVersion = $build_version"
