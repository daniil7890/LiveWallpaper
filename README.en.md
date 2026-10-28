<p align="center">
  <img src="assets/icon.png" width="160" alt="LiveWallpaper icon">
</p>

<h1 align="center">LiveWallpaper</h1>

<p align="center">
  Live video wallpapers for macOS. Native, lightweight, lives in the menu bar.
</p>

<p align="center">
  <a href="README.md">Русский</a> | <b>English</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple">
  <img src="https://img.shields.io/badge/Apple%20Silicon-arm64-7b2cbf">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white">
</p>

---

## Features

- 🎬 **Any video as a wallpaper** — mp4, mov, HEVC; seamless looping via `AVPlayerLooper`
- 🖥 **Every display and every Space** — the window sits below the desktop icons, and clicks pass straight through
- 🔋 **Battery friendly** — pauses automatically when:
  - the wallpaper is covered by windows or a full-screen app
  - the screen is locked or asleep
  - the Mac is running on battery (can be turned off in the menu)
- 🔇 Sound is off by default and can be turned on with one click
- ↔️ "Fill screen" and "Fit without cropping" modes
- 🚀 Launch at login
- 🪶 No Dock icon, no extra windows — just a ▶ icon in the menu bar

## Installation

1. Download `LiveWallpaper-1.0.zip` from [Releases](../../releases/latest).
2. Unzip it and drag **LiveWallpaper.app** into Applications.
3. The app is not notarized by Apple, so macOS will block it on first launch. Run this in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/LiveWallpaper.app
   ```

   or open **System Settings → Privacy & Security** and click **Open Anyway**.
4. Launch the app and pick a video.

> The prebuilt app is for Apple Silicon only (M1 and newer). On Intel Macs, build it from source.

## Usage

Everything is controlled from the ▶ icon in the menu bar. The menu is in Russian; the original labels are shown in parentheses.

| Item | What it does |
|---|---|
| Choose video… (Выбрать видео…) | Opens a file picker (⌘O) |
| Pause / Resume (Пауза / Продолжить) | Manual pause (⌘P) |
| Sound (Звук) | Turns the video's audio on |
| Fit without cropping (Вписать без обрезки) | Shows the whole video instead of filling the screen |
| Pause on battery (Пауза от батареи) | Stops the video when not charging |
| Launch at login (Запускать при входе) | Autostart via `SMAppService` |

The chosen video and settings are remembered between launches.

**Where to get wallpapers:** any looping clip works — for example from [Moewalls](https://moewalls.com), [MotionBgs](https://motionbgs.com), or your own recordings. HEVC (H.265) works best: it is hardware-decoded and barely touches the CPU.

## Building from source

You only need the Command Line Tools (`xcode-select --install`); Xcode is not required.

```bash
git clone https://github.com/daniil7890/LiveWallpaper.git
cd LiveWallpaper
./build.sh
```

The script builds `LiveWallpaper.app`, signs it with an ad-hoc signature, installs it to `~/Applications` and launches it. You can also double-click `build.command` in Finder; the build log is saved to `build.log`.

## How it works

- Each display gets a borderless window at level `desktopWindow + 1` — above the desktop picture but below the icons.
- All windows share a single `AVQueuePlayer`, so the video is decoded once for every display.
- Visibility is tracked through `NSWindow.occlusionState`; screen sleep and lock through `NSWorkspace` notifications and `com.apple.screenIsLocked`; power source through `IOKit.ps`.

```
Sources/LiveWallpaper/main.swift   — the whole app (~250 lines)
Info.plist                         — LSUIElement, icon, bundle id
build.sh / build.command           — builds the .app
AppIcon.icns                       — the icon
```

## License

[MIT](LICENSE)
