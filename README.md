# Netspeed

Live download and upload speed in the [Omarchy](https://omarchy.org/) bar. A fixed-width widget sampled from interface byte counters, so the bar never shifts as speeds rise and fall.

![Netspeed preview](preview.png)

## Install

```bash
omarchy plugin add https://github.com/jhonoryza/omarchy-netspeed --enable
```

Pick the `right` section when prompted (or any section you prefer).

## Remove

```bash
omarchy plugin remove vm.netspeed
```

Or manually:

1. Delete the plugin folder:
   ```bash
   rm -rf ~/.config/omarchy/plugins/vm.netspeed
   ```
2. Remove the `"id": "vm.netspeed"` entry from the bar layout in `~/.config/omarchy/shell.json`.
3. Restart the shell:
   ```bash
   omarchy restart shell
   ```

## Usage

- The bar shows `↓` + download rate and `↑` + upload rate (e.g. `↓ 724 KB/s ↑ 30 KB/s`).
- Hover for a tooltip with the interface name and both rates.
- Left/middle click refreshes the reading immediately.
- Right click toggles the upload readout on/off.

## Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `refreshSeconds` | integer 1–5 | 1 | Sampling interval in seconds |
| `showUpload` | boolean | true | Show the upload rate |

## Requirements

- Omarchy 4.x with Quickshell
- `ip` (iproute2) and `bash`
- A default route (shows `--` when offline)

## How it works

`netspeed.sh` prints one JSON line per run with the active interface's raw
`/sys/class/net/<iface>/statistics/{rx,tx}_bytes` counters plus a timestamp.
`BarWidget.qml` computes rates as deltas between successive samples, so the
script stays stateless. The first sample after start or an interface switch
only seeds the baseline and shows `0 B/s` instead of a spike.

## License

[MIT](LICENSE)
