# MangaPageView example app

This directory contains a demo or showcase app demonstrating what `MangaPageView` can do.

## Prerequisites

Be sure to run:

```shell
flutter create .
```

under this directory to set up native platform files for the first time.

If you are running the example that needs image taken from network, be sure to enable internet permissions on the specific platform files.
 
Example:
- On Android: add this line inside `app/src/.../AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
- On macOS: add these lines under `Runner/DebugProfile.entitlements` or `Runner/Release.entitlements`
```xml
<key>com.apple.security.network.client</key>
<true/>
```