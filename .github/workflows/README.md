# GitHub Workflows

## build-android-x86_64.yml

This workflow builds Android APK specifically for x86_64 architecture.

### Triggers
- Manual dispatch (workflow_dispatch) with optional version parameter
- Push to tags starting with 'v'
- Pull requests that modify Android, lib, or pubspec.yaml files

### Outputs
- APK artifact uploaded to the workflow run
- If triggered by a tag, the APK is also attached to the release

### Usage
1. **Manual Trigger**: Go to Actions tab → "Build Android APK (x86_64)" → "Run workflow"
2. **Tag Release**: Create and push a tag starting with 'v' (e.g., `git tag v1.0.8 && git push origin v1.0.8`)

The resulting APK will be named `clashmi_{version}_android_x86_64.apk`