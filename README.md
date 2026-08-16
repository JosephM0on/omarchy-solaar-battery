# Logitech Battery for Omarchy

Bar widget that shows battery levels for Logitech peripherals through
[Solaar](https://pwr-solaar.github.io/Solaar): keyboard, mouse, and headset.

Tested with a G915 TKL, PRO X Wireless, and G733 headset.

The G733 percentage is scaled from its real voltage range (about 3.5–4.0 V).
Solaar’s own table assumes 4.2 V = 100%, so a full G733 otherwise tops out
around 80%.

## Install

Needs [Solaar](https://pwr-solaar.github.io/Solaar) on `PATH` or as Flatpak
`io.github.pwr_solaar.solaar`.

```bash
omarchy plugin add https://github.com/JosephM0on/omarchy-solaar-battery.git --enable
```

The widget lands on the right side of the bar. Move it with:

```bash
omarchy bar move josephm0on.solaar-battery --before omarchy.power
```

## Use

- Left click: refresh now
- Right click: open Solaar
- Hover: name, percent, voltage, status
- Low battery (≤20% and not charging) uses the bar’s urgent color

Refresh interval defaults to 60 seconds (`refreshIntervalSec` in `shell.json`).
