# Bauhaus Clock

A minimal Bauhaus-style analogue clock in two forms:

- **Web clock** (`web/index.html`): one self-contained offline HTML file (SVG, embedded font, no network).
  Live at **https://clogwog.net/projects/clock/**
- **macOS screensaver** (`screensaver/`): native Swift / Core Graphics `.saver` that bounces DVD-style,
  explodes on a corner hit, respawns in a new colour and dims at night.

## Platform support

The screensaver is macOS only (macOS 13 Ventura or later, Apple Silicon and Intel; it's a native `.saver` bundle) and won't run on Windows or Linux. The web clock works in any modern browser on any device.

## Screenshots

| Web: Noir (default) | Web: light dial | Web: Lume |
|---|---|---|
| ![Web clock, Noir dial](screenshots/web-noir.png) | ![Web clock, White dial](screenshots/web-light.png) | ![Web clock, Lume on](screenshots/web-lume.png) |

**Screensaver: bouncing**

![Screensaver bouncing](screenshots/saver-bounce.png)

**Screensaver: corner-hit explosion**

![Screensaver explosion](screenshots/saver-explode.png)

| Screensaver thumbnail | Screensaver Lume |
|---|---|
| ![Screensaver thumbnail](screenshots/saver-thumbnail.png) | ![Screensaver Lume](screenshots/saver-lume.png) |

## Web clock

Open `web/index.html` in any browser. Settings (gear button, bottom right) persist in `localStorage`:
dial colour (default Noir), movement (default Digital), layout, second time zone, size, seconds,
numerals, night mode, burn-in protection, fonts, **Lume (glow)** and language (10 languages).

## Screensaver

Requirements: macOS 13+, Xcode command-line tools.

```sh
cd screensaver
./build.sh
```

`build.sh` runs the test harness (`main.swift`, must print `ALL PASS`), builds a universal
(arm64 + x86_64) `BauhausClock.saver`, ad-hoc signs it, installs it to `~/Library/Screen Savers/`
and restarts `legacyScreenSaver`. Then pick **Bauhaus Clock** in System Settings → Screen Saver.

**Options…** in System Settings:
- *Lume: glowing cyan markers and hands*
- *Turn lume on automatically at night (10pm–7am, after 3 min)* (on by default)

Files: `Clock.swift` (drawing), `Sim.swift` (bounce/explosion/dimming state machine), `View.swift`
(ScreenSaverView + options sheet), `main.swift` (tests), `Info.plist`, `ClockNum.ttf` (digit subset of
Michroma, SIL OFL; used by the web clock's numerals, bundled for the screensaver), thumbnails.

## Deploy

See [DEPLOY.md](DEPLOY.md).
