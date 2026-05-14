---
name: ios-version-update
description: Update the Gemma4 iOS app version across the real app version fields. Use when the user wants to bump the app version, set a new release number, sync marketing/build versions, or verify where the iOS app version is defined in this repository.
---

# iOS Version Update

Use this skill when the user wants to change the Gemma4 iOS app version.

## Scope

This repo's real app version fields live in:

- `ios/project.yml`
- `ios/Gemma4App/Info.plist`
- `ios/Gemma4App.xcodeproj/project.pbxproj`

Default behavior:

1. Set `MARKETING_VERSION` to the requested version.
2. Set `CURRENT_PROJECT_VERSION` to the same value unless the user asks for a separate build number.
3. Set `CFBundleShortVersionString` to the same value.
4. Set `CFBundleVersion` to the same value unless the user asks for a separate build number.

Do not mass-edit `version` strings in vendored dependencies, docs, licenses, or generated third-party files unless the user explicitly asks.

## Fast Workflow

1. Search only the app-owned version fields:

```bash
rg -n "MARKETING_VERSION|CURRENT_PROJECT_VERSION|CFBundleShortVersionString|CFBundleVersion" \
  ios/project.yml \
  ios/Gemma4App/Info.plist \
  ios/Gemma4App.xcodeproj/project.pbxproj
```

2. Update the files with the requested version.
3. Re-run the same `rg` command to confirm every app-owned version field matches.
4. Report exactly which files changed.

## Preferred Path

Use the bundled script for consistent edits:

```bash
bash skills/ios-version-update/scripts/update_ios_version.sh 2.0
```

If the user wants separate values, pass both:

```bash
bash skills/ios-version-update/scripts/update_ios_version.sh 2.0 42
```

Meaning:

- first arg: marketing version / short version
- second arg: build version

If the second arg is omitted, the script uses the first arg for both.

## Validation

After running the script, confirm:

- `ios/project.yml` has the new `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
- `ios/Gemma4App/Info.plist` has the new `CFBundleShortVersionString` and `CFBundleVersion`
- `ios/Gemma4App.xcodeproj/project.pbxproj` has the new `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both Debug and Release blocks

## Constraints

- Keep edits limited to app-owned version fields by default.
- Prefer exact `rg` verification over broad text search results.
- If the repo later adopts `xcodegen` regeneration as the source of truth, keep `project.yml` and the generated `.pbxproj` aligned in the same change.
