# ClaudeMenu

A macOS menu bar app that displays your Claude Code usage limits (5-hour session and 7-day weekly) as small progress bars, updated in real time.

![Menu bar icon showing two progress bars](https://img.shields.io/badge/macOS-13%2B-blue)

## Features

- **Menu bar progress bars** — two tiny bars in your menu bar showing session (5h) and weekly (7d) usage at a glance, with percentage labels
- **Dynamic color thresholds** — a dotted time-marker line shows where you "should" be based on elapsed time in each window:
  - **Green**: usage at or below the time marker
  - **Orange**: usage above the time marker (ahead of expected pace)
  - **Red**: usage has consumed more than half of the remaining budget past the marker
- **Popover detail view** — click for full percentages, progress bars, and reset countdowns
- **Bundled statusline binary** — no `jq` dependency; auto-configures Claude Code's `statusLine` setting on first launch
- **Wraps existing statuslines** — if you already have a statusline command, it will be preserved and chained via `--wrap`
- **Auto-replaces on relaunch** — re-opening the app terminates any existing instance

## Install

Download `ClaudeMenu.app.zip` from the [latest release](https://github.com/joshado/ClaudeMenu/releases/latest), unzip, and move to `/Applications` (or anywhere you like).

On first launch, the app will ask to configure Claude Code's statusline. Accept, then restart your Claude Code session so it starts emitting usage data.

## Build from source

```bash
cd ClaudeMenu
swift build -c release
```

To create the `.app` bundle:

```bash
mkdir -p ../ClaudeMenu.app/Contents/{MacOS,Resources}
cp .build/release/ClaudeMenu ../ClaudeMenu.app/Contents/MacOS/
cp .build/release/claude-statusline ../ClaudeMenu.app/Contents/Resources/
cp ../Info.plist ../ClaudeMenu.app/Contents/
```

## How it works

1. The app registers a `statusLine` command in `~/.claude/settings.json` pointing to the bundled `claude-statusline` binary
2. Claude Code pipes JSON (including `rate_limits`) to this binary after each assistant message
3. The binary writes parsed data to `/tmp/claude-rate-limits.json`
4. The menu bar app polls this file every 10 seconds and redraws the icon

## Requirements

- macOS 13 (Ventura) or later
- Claude Code with statusline support (v2.1.80+)
- A Claude Pro or Max subscription (rate limit data is only available for subscribers)

## License

MIT
