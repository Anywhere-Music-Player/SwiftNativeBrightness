# Publishing signed updates

The app reads `https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/releases/latest/download/appcast.xml`. Each published latest release must include that file and its matching ZIP. Sparkle follows the feed's version-specific GitHub download URL, verifies the Ed25519 signature and the app's code signature, and offers installation. Never reuse or reset `CURRENT_PROJECT_VERSION`; Sparkle compares build numbers.

The first published release with the updater is 26.10.2 (build 3); the 26.10.1 implementation was not published separately. Version 26.10.0 needs one manual replacement because it has no active updater.

## Sign and notarize

Archive the final committed source with the SwiftNativeBrightness scheme, Release configuration, both architectures and your development team. Use Xcode's Developer ID distribution with automatic signing and upload for notarization. For command-line distribution, use `xcodebuild -exportArchive` with an export options plist containing `method=developer-id`, `destination=upload`, `signingStyle=automatic`, your `teamID` and `manageAppVersionAndBuildNumber=false`, plus `-allowProvisioningUpdates`.

After Apple approves the submission, use `xcodebuild -exportNotarizedApp -archivePath … -exportPath …`. Verify the exported app with `codesign --verify --deep --strict`, `xcrun stapler validate` and `spctl --assess --type execute --verbose=4`. Xcode can use cloud-managed Developer ID signing through the connected account even when `security find-identity` only lists a local development identity.

## Package the update

Sparkle tools are in the resolved package's `SourcePackages/artifacts/sparkle/Sparkle/bin` folder in DerivedData. Use the tools from the same package as the app:

```sh
export SPARKLE_TOOLS="/path/to/SourcePackages/artifacts/sparkle/Sparkle/bin"
./Scripts/make-update.sh /path/to/SwiftNativeBrightness.app /path/to/empty-output
```

An optional third argument supplies a short HTML release-note fragment (under 1000 bytes), embedded directly into the feed.

The private Ed25519 key stays in the login Keychain under account `com.anywheremusicplayer.SwiftNativeBrightness`. The script uses that key without exporting it and checks its public key against the app before packaging. Preserve this Keychain item when moving release work to another Mac; never commit a private key.

Run `./Tests/check-update-feed.sh /path/to/output/appcast.xml /path/to/output/SwiftNativeBrightness-VERSION-buildBUILD.zip`. This verifies feed metadata and the archive signature against the app's public key, including rejection of modified data.

## Publish

Create a draft GitHub release for the validated commit/tag, upload the generated ZIP, checksum and `appcast.xml`, and then publish it as the latest release. Do not upload a new ZIP under an existing signature. Do not mark a release as latest unless all three assets are present.

After publishing, check that the feed URL above works and repeat the signature check with files downloaded from GitHub. Test Sparkle's information-only check from an isolated fixture bundle with a lower build number; it must detect the newer build without installing it. Then test the same check at the current build; it must report no update.
