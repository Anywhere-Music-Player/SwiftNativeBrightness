# Publishing releases

The app's **Check for updates** action opens this project's GitHub Releases page. Users download the ZIP, quit the running app, and replace it in Applications.

## Sign and notarize

Archive the final committed source with the SwiftNativeBrightness scheme, Release configuration, both architectures and your development team. Use Xcode's Developer ID distribution with automatic signing and upload for notarization. For command-line distribution, use `xcodebuild -exportArchive` with an export options plist containing `method=developer-id`, `destination=upload`, `signingStyle=automatic`, your `teamID` and `manageAppVersionAndBuildNumber=false`, plus `-allowProvisioningUpdates`.

After Apple approves the submission, use `xcodebuild -exportNotarizedApp -archivePath … -exportPath …`. Verify the exported app with `codesign --verify --deep --strict`, `xcrun stapler validate` and `spctl --assess --type execute --verbose=4`. Xcode needs a connected Apple Developer account for cloud-managed Developer ID signing, even when a local Apple Development identity is available.

## Package and publish

```sh
./Scripts/make-release.sh /path/to/SwiftNativeBrightness.app /path/to/empty-output
```

The script verifies the app's identity, signature, notarization and Gatekeeper assessment, then creates a ZIP and SHA-256 checksum. Create a draft GitHub release for the validated commit/tag, upload both files, and publish it after checking the assets. Download the published files and verify the checksum again.
