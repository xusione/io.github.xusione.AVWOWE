# AVWOWE

**Interactive Media Player & Kiosk System**

AVWOWE turns media collections into nonstop on-screen magic — continuous
playback, scrolling tickers, dynamic overlays, picture-in-picture layers,
live remote content, and frame-accurate PNG export. Built for home screens,
storefront displays, events, and ambient installations.

Homepage: <https://avwowe.xusione.com/>

> AVWOWE is proprietary software. See [LICENSE](LICENSE) for terms.
> This repository packages the application as a [Flatpak](https://flatpak.org/).

## Features

- **Always On** — point at local folders and cycle through media continuously,
  with optional automatic jump cuts for a montage look.
- **Advanced Tickers** — scrolling text bars from static text, local files, or
  live URLs, with full font/color/size/background control.
- **Dynamic Overlays** — animated or static corner watermarks, full-screen
  frames, CRT scanlines, film grain.
- **Picture in Picture** — animated JPG/PNG/GIF layers that drift, spin, and
  tilt across the display.
- **Live Content & Remote Config** — auto-detect added/removed files and pull
  live text from remote URLs without restarting.
- **High-Fidelity Export** — export compositions as frame-accurate PNG
  sequences for video rendering.

## Install

Once published on Flathub:

```bash
flatpak install flathub com.xusione.AVWOWE
flatpak run com.xusione.AVWOWE
```

## Build the Flatpak locally

Requires `flatpak` and `flatpak-builder`, plus the Freedesktop 24.08 runtime/SDK:

```bash
flatpak install flathub org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08

# Build and install into the user installation
flatpak-builder --user --install --force-clean build-dir com.xusione.AVWOWE.yml

flatpak run com.xusione.AVWOWE
```

To verify nothing is missing at runtime inside the sandbox:

```bash
flatpak run --command=sh com.xusione.AVWOWE \
  -c 'LD_LIBRARY_PATH=/app/lib ldd /app/bin/AVWOWE | grep "not found"'
```

## File access

By default the sandbox can read/write the standard media directories
(`~/Videos`, `~/Pictures`, `~/Music`). If your media lives elsewhere, grant the
path once — it persists across reboots and updates:

```bash
flatpak override --user com.xusione.AVWOWE --filesystem=/path/to/media
```

## Kiosk deployment

`avwowe-kiosk.service` is a host-side systemd **user** unit (it is not shipped
inside the Flatpak). Install it on the kiosk machine to auto-start and restart
the app within a graphical session:

```bash
cp avwowe-kiosk.service ~/.config/systemd/user/
systemctl --user enable --now avwowe-kiosk.service
```

Pair it with the `flatpak override` above so configured media folders remain
accessible after reboots and are picked up automatically on rescan.

## License

Copyright © 2026 XUSIONE. All rights reserved. AVWOWE is proprietary software;
use is governed by the [End User License Agreement](LICENSE).
