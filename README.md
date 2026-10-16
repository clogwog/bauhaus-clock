# Bauhaus Clock

<p align="center">
<img alt="Bauhaus clock on the Cream dial" src="screenshots/hero.png" width="560">
</p>

A minimal Bauhaus-style analogue clock in two forms:

- **Web clock** (`web/index.html`): one self-contained offline HTML file (SVG, embedded font, no network).
  [Live demo](https://clogwog.net/projects/clock/)
- **macOS screensaver** (`screensaver/`): native Swift / Core Graphics `.saver` that bounces DVD-style,
  explodes on a corner hit, respawns in a new colour and dims at night.

## Platform support

The screensaver is macOS only (macOS 13 Ventura or later, Apple Silicon and Intel; it's a native `.saver` bundle) and won't run on Windows or Linux. The web clock works in any modern browser on any device.

## Features

### Web clock

- 19 dial colours (Noir is the default). A caption under the swatches names the selected dial.
- Chronograph: a black chronograph dial with a tachymètre bezel, lume batons, and three subdials. The seconds subdial at 9 runs; the subdials at 3 and 6 are decorative. Selecting this dial sets the movement to Mechanical. With Lume on, the face goes dark and only the green lume batons and hand strips glow.

  ![Chronograph dial](screenshots/web-speedmaster.png)

- Diver: a navy wave dial with a blue dive bezel and a lume pip, round lume markers (bars at 12, 3, 6 and 9), skeleton hands, and a red-tipped seconds hand. A date window at 3 shows that clock's own date, including the second time zone in dual-clock mode. With Lume on, the face goes dark and the lume pip, markers, and hand tips glow.

  ![Diver dial](screenshots/web-diver.png)

- Pilot: a black dial with a cream slide-rule bezel (full outer and inner rings, with a log scale and time markings), gilt hour numerals, and three subdials. The seconds subdial at 9 runs; the subdials at 3 and 6 are decorative. The hands are aged-cream lume batons with a dark outline. With Lume on, the face goes dark and the numerals, 12 o'clock triangle, and hand strips glow a warm yellow-green.

  ![Pilot dial](screenshots/web-pilot.png)
- Three movements. Quartz ticks with a slight overshoot, Mechanical steps at eight beats a second, and Digital sweeps the seconds hand smoothly (Digital is the default). Hour and minute hands sweep on every movement.
- Classic and Compact layouts (Classic is the default; Compact leaves out the minute ticks).
- 10 languages.
- Subtle matte Bauhaus style, with grooved hour bars and slim tapered hands.
- Crisp hand shadows lit from the top-right. Multiply blending darkens whatever they fall on. Lume hides the shadows.
- Lume mode: cyan glow on a black dial.
- Optional hour numerals and seconds hand (both on by default).
- Size slider.
- Dual clock with a second time zone. Each location label is followed by a small sun and AM, or a crescent moon and PM, for that clock's time zone (cyan in Lume).

  ![Dual clock with AM and PM](screenshots/dual-ampm.png)

- Optional night dimming from 10pm–7am (off by default; the clock fades to 45% opacity).
- Burn-in drift (on by default).
- Settings remembered in the browser.
- Open settings with the gear, or the `s` or `,` keys. Escape, or a click outside the panel, closes it. The panel scrolls on a phone.
- One self-contained offline HTML file.

### Screensaver

Version 1.17. Native macOS `.saver` bundle (Core Graphics drawing, no web view).

- All 19 dials, including Chronograph, Diver and Pilot. Those three have dark lume views (Chronograph and Diver glow green; Pilot glows a warm yellow-green). The other dials use the cyan lume.
- Quartz, Mechanical and Digital movements (Digital is the default). Quartz ticks with a slight overshoot, Mechanical steps at eight beats a second, and Digital sweeps the seconds hand.
- A seconds-hand toggle (on by default). Classic and Compact styles; Compact leaves the minute ticks off the colour dials.
- Size is 2/3, 1/2, or 1/3 of the screen height (2/3 by default). It drifts at about 30 pixels a second on a 1080p display. Bounce is on by default; turning it off holds the clock in the centre.
- A corner hit, within a few pixels, explodes the clock (on by default). It then switches to a different dial, which can be turned off.
- Night dimming after 3 minutes from 10pm–7am, fading to about a third of full brightness (on by default).
- Options sheet: a face picker for all 19 dials, plus movement, style, size, seconds hand, lume (off unless ticked), automatic night lume (off by default), night dimming, bounce, explode, and change dial after an explosion. Settings are saved so they persist.

  ![All screensaver dials](screensaver/dials-sheet.png)

- Preview thumbnail for System Settings.
- Universal build for Apple Silicon and Intel.
- A test harness (`main.swift` must print `ALL PASS`).

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

Version 1.17. Requirements: macOS 13+, Xcode command-line tools.

```sh
cd screensaver
./build.sh
```

`build.sh` runs the test harness (`main.swift`, must print `ALL PASS`), builds a universal
(arm64 + x86_64) `BauhausClock.saver`, ad-hoc signs it, installs it to `~/Library/Screen Savers/`
and restarts `legacyScreenSaver`. Then pick **Bauhaus Clock** in System Settings → Screen Saver.

**Options…** in System Settings: a face picker, movement (Quartz, Mechanical, Digital), style (Classic, Compact), size (2/3, 1/2, or 1/3 of the screen height), seconds hand, lume (off unless ticked), automatic night lume (off by default), night dimming (10pm–7am, after 3 min), bounce, explode on a corner hit, and change dial after an explosion.

Files: `Clock.swift` (drawing), `Faces.swift` (Chronograph, Diver and Pilot), `Sim.swift` (bounce/explosion/dimming state machine), `View.swift`
(ScreenSaverView + options sheet), `main.swift` (tests), `Info.plist`, `ClockNum.ttf` (digit subset of
Michroma, SIL OFL; used by the web clock's numerals, bundled for the screensaver), thumbnails.

## Inspiration

This project was inspired by the [Bauhaus Clock](https://bauhausclock.com/) app, a commercial Mac screensaver and iPhone/iPad app. This is an independent fan recreation, not affiliated with it, and uses none of its assets. The later watch-style details were inspired by reference photos.
