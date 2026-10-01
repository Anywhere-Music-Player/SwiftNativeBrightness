<div align="center">

<img src=".github/Icon-cropped.png" width="128" alt="SwiftNativeBrightness app icon">

# SwiftNativeBrightness

**Your displays, one menu away.**

Control brightness, volume and contrast from the macOS menu bar or your keyboard.

[![macOS](https://img.shields.io/badge/macOS-14%2B-007AFF)](#macos-compatibility)
[![Swift](https://img.shields.io/badge/Swift-AppKit%20%2B%20SwiftUI-F05138?logo=swift&logoColor=white)](#how-to-build)
[![License: MIT](https://img.shields.io/badge/license-MIT-3fb950)](License.txt)

**[Build from source](#how-to-build)** · **[Releases](https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/releases)** · **[Issues](https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/issues)**

</div>

SwiftNativeBrightness is a free, open-source macOS menu bar app for managing built-in and external displays. It combines hardware controls with software dimming, native menu sliders, a sidebar settings window and system appearance controls.

It is an independently maintained fork of [MonitorControl](https://github.com/MonitorControl/MonitorControl), with system appearance controls adapted from [Crisp](https://github.com/didriksg/Crisp). This also continues the idea behind my older [NativeDisplayBrightness](https://github.com/Anywhere-Music-Player/NativeDisplayBrightness) app.

**Build from source for now.** There is no published SwiftNativeBrightness release yet. MonitorControl downloads and the `monitorcontrol` Homebrew cask install the upstream app, not this one.

<p align="center">
  <img src=".github/screenshot.png" width="300" alt="SwiftNativeBrightness menu with display brightness sliders, system appearance controls and Night Shift temperature">
</p>

The screenshots were captured before the rename.

## Quick start

[Build from source](#how-to-build), then copy **SwiftNativeBrightness.app** to Applications. Future binaries will be published on this project's [Releases page](https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/releases).

1. Open SwiftNativeBrightness and click its brightness icon in the menu bar.
2. Move a display's brightness slider, or use your keyboard brightness keys.
3. Open **Settings…** to customize keyboard shortcuts and per-display controls.

Native Apple brightness and media keys require **Accessibility** permission in **System Settings → Privacy & Security → Accessibility**. The renamed app has its own bundle identifier and preferences, so grant permission and enable launch at login for SwiftNativeBrightness separately. Run only one display-control app at a time to avoid conflicting adjustments.

**Check for updates** opens this project's Releases page. Automatic updates are not configured; the app does not use MonitorControl's update feed or signing key.

## Major features

| Area | Controls |
| --- | --- |
| Brightness | Hardware backlight control, smooth transitions, software dimming and combined dimming below the hardware minimum. |
| Audio & contrast | Volume and contrast on monitors that expose these controls through DDC/CI. |
| Multiple displays | Per-display sliders, synchronized brightness and keyboard shortcuts. |
| System appearance | Dark Mode, Night Shift, True Tone and Night Shift temperature controls. |
| Settings | Resizable sidebar window, display information, launch at login and advanced hardware options. |

<details>
<summary>Full feature list</summary>

- Control your display's brightness, volume and contrast!
- Shows native OSD for brightness and volume.
- Supports multiple protocols to adjust brightness: DDC for external displays (brightness, contrast, volume), native Apple protocol for Apple and built-in displays, Gamma table control for software dimming, shade control for AirPlay, Sidecar and Display Link devices and other virtual screens.
- Supports smooth brightness transitions.
- Seamlessly combined hardware and software dimming extends dimming beyond the minimum brightness available on your display.
- Synchronize brightness from built-in and Apple screens - replicate Ambient light sensor and touch bar induced changes to a non-Apple external display!
- Sync up all your displays using a single slider or keyboard shortcuts.
- Allows dimming to full black.
- Support for custom keyboard shortcuts as well as standard brightness and media keys on Apple keyboards.
- Dozens of customization options to tweak the inner workings of the app to suit your hardware and needs (don't forget to enable `Show advanced settings` in app Settings).
- Simple, unobtrusive UI to blend in to the general aesthetics of macOS.
- Resizable settings window with sidebar navigation and grouped General and Appearance controls.
- Native menu sliders with optional current display resolution labels.
- Launch at login directly through macOS Service Management, without a separate helper app.
- System Dark Mode, Night Shift and True Tone share one option in Settings > Appearance. Night Shift temperature has a separate option. Both are enabled by default. Show percentages also controls the Night Shift temperature value.
- Completely FREE.

</details>

For additional features, more advanced brightness control with XDR/HDR brightness upscaling and support for more Mac models and displays, check out [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme)!

### Settings

<div align="center">
<img src=".github/settings-general.png" width="940" alt="SwiftNativeBrightness settings with sidebar navigation and grouped General controls"/>
</div>

Use the sidebar to switch between General, Appearance, Keyboard, Displays and About.
General includes launch at login, updates and brightness behavior. Appearance controls
which sliders, display information and system controls appear in the menu. Keyboard
and Displays retain the existing shortcuts and per-display options, including advanced
DDC settings.

### macOS compatibility

SwiftNativeBrightness requires macOS 14 or later. The project version is 26.0.0; this is not a published release. For older macOS versions, see [upstream MonitorControl releases](https://github.com/MonitorControl/MonitorControl/releases).

Native macOS OSD behavior depends on the OS version. On Tahoe, the OSD percentage may not show or update.

### Supported displays

- Most modern LCD displays from all major manufacturers supported implemented DDC/CI protocol via USB-C, DisplayPort, HDMI, DVI or VGA to allow for hardware backlight and volume control.
- Apple displays and built-in displays are supported using native protocols.
- LCD and LED Televisions usually do not implement DDC, these are supported using software alternatives to dim the image.
- DisplayLink, Airplay, Sidecar and other virtual screens are supported via shade (overlay) control.

Notable exceptions for hardware control compatibility:

- DDC control using the built-in HDMI port of the 2018 Intel Mac mini, the built-in HDMI port of all M1 Macs (MacBook Pro 14" and 16", Mac Mini, Mac Studio) and the built-in HDMI port of the entry level M2 Mac mini are not supported. Use USB-C instead or get [BetterDisplay](https://betterdisplay.pro) for full DDC control over HDMI with these Macs as well for free. Software-only dimming is still available for these connections.
- Some displays (notably EIZO) use MCCS over USB or an entirely custom protocol for control. These displays are supported with software dimming only.
- DisplayLink docks and dongles do not allow for DDC control on Macs, only software dimming is available for these connections.

## Contributing

[Report an issue](https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/issues) or [open a pull request](https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/pulls) targeting `dev/swiftnativebrightness`. Include your macOS version, display model, connection type and reproduction steps for display problems.

## How to build

Use Xcode with a macOS SDK supporting the macOS 14 deployment target. The project also uses [SwiftLint](https://github.com/realm/SwiftLint), [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) and [BartyCrouch](https://github.com/Flinesoft/BartyCrouch) for its build scripts.

```sh
git clone --single-branch --branch dev/swiftnativebrightness https://github.com/Anywhere-Music-Player/SwiftNativeBrightness.git
cd SwiftNativeBrightness
open SwiftNativeBrightness.xcodeproj
```

Select the **SwiftNativeBrightness** scheme and your signing team, then build or run. Xcode resolves package dependencies when the project opens; if needed, use **File → Packages → Resolve Package Versions**.

### Checks

```sh
./Tests/test-night-shift.sh
./Tests/test-settings.sh
./Tests/test-settings-window.sh
```

See [Tests/README.md](Tests/README.md) for requirements and coverage limits. These checks do not establish physical-display compatibility.

### Third party dependencies

- [MediaKeyTap](https://github.com/MonitorControl/MediaKeyTap)
- [Settings](https://github.com/sindresorhus/Settings)
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [Sparkle](https://github.com/sparkle-project/Sparkle)

## Credits

Original MonitorControl and Crisp copyright notices and MIT licenses are preserved. Thanks to both projects and their contributors.

- [@waydabber](https://github.com/waydabber), maintainer, developer of [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme).
- [@the0neyouseek](https://github.com/the0neyouseek) - honorary maintainer
- [@JoniVR](https://github.com/JoniVR) - honorary maintainer
- [@alin23](https://github.com/alin23) - spearheaded M1 DDC support, developer of [Lunar](https://lunar.fyi)
- [@mathew-kurian](https://github.com/mathew-kurian/) (original developer)
- [@Tyilo](https://github.com/Tyilo/) (fork)
- [@Bensge](https://github.com/Bensge/) - (used some code from his project [NativeDisplayBrightness](https://github.com/Bensge/NativeDisplayBrightness))
- [@nhurden](https://github.com/nhurden/) (for the original MediaKeyTap)
- [@kfix](https://github.com/kfix/ddcctl) (for ddcctl)
- [@reitermarkus](https://github.com/reitermarkus) (for Intel DDC support)
- [javierocasio](https://www.deviantart.com/javierocasio) (app icon background)

## License

MonitorControl is available under the [MIT License](License.txt). UI code derived from Crisp retains its [MIT copyright notice](MonitorControl/UI/Crisp-LICENSE.txt). Third-party dependencies retain their own licenses.
