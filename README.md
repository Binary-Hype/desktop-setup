# desktop-setup

macOS tiling setup: **AeroSpace** (window manager) + **SketchyBar** (status bar)
+ **JankyBorders** (window borders), sharing one colour palette.

Based on [SgSiegens/macos-dotfiles](https://github.com/SgSiegens/macos-dotfiles),
reduced to those three tools and adapted (no pywal — colours are static).

## Install on a new Mac

```bash
git clone git@github.com:Binary-Hype/desktop-setup.git ~/Projects/desktop-setup
cd ~/Projects/desktop-setup
./install.sh --dry-run   # see what it would do
./install.sh
```

Then do the manual steps it prints — the important one is granting **AeroSpace
Accessibility permission**, without which it cannot start.

Existing configs are moved to `<name>.backup-<timestamp>`, never overwritten.

### Installing only parts

All three components install by default. Pick a subset:

```bash
./install.sh --list                    # show components
./install.sh --only sketchybar         # just the bar
./install.sh --only=aerospace,borders  # comma-separated also works
./install.sh --sketchybar --borders    # or name them directly
./install.sh --skip aerospace          # everything except the WM
```

Components: `aerospace`, `sketchybar`, `borders`, `raycast`.

| flag | effect |
|---|---|
| `--only <list>` | install only these components |
| `--skip <list>` | install everything except these |
| `--aerospace` / `--sketchybar` / `--borders` / `--raycast` | shorthand for `--only` |
| `--list` | show the components and what each pulls in |
| `--dry-run` | print everything, change nothing |
| `--no-deps` | skip Homebrew, only place configs and restart services |
| `--no-services` | place configs but start nothing |

Each component carries its own dependencies (`aerospace` → the cask;
`sketchybar` → the formula, Nerd Font, `blueutil`, `jq`; `borders` → the
formula; `raycast` → the cask), so a partial install only pulls what it needs.

`raycast` is **app-only**: it installs the launcher but places no files, because
Raycast keeps its settings in your Raycast account rather than on disk.

**Two cross-dependencies**, both handled automatically:

- `bordersrc` reads its palette from `sketchybar/colors.sh` when present, so
  recolouring the bar recolours the borders. Without it, it falls back to the
  same colours inlined in `bordersrc`, so `borders` works standalone.
- `gaps.outer.top` in `aerospace.toml` reserves vertical room for the bar
  (`BAR_Y_OFFSET + BAR_HEIGHT + gap`). Installed **without** sketchybar that
  would be ~40pt of dead space above every window, so `install.sh` rewrites it
  to a plain `6`. The repo copy keeps the bar-aware value, so adding sketchybar
  later and re-running `./install.sh --only aerospace` restores it.

## Update the repo from this machine

```bash
./sync.sh              # copy ~/.config -> repo, show the diff
./sync.sh --commit     # ...and commit it
./sync.sh --dry-run    # preview only
git push
```

`sync.sh` is the only thing that decides what is tracked (see `TRACKED` in the
script). It copies **one way**: system → repo. `install.sh` goes the other way.

## What's in here

```
config/aerospace/aerospace.toml   workspaces, keybindings, gaps, window rules
config/aerospace/scripts/         helpers invoked by keybindings
config/borders/bordersrc          border width + colours (sources colors.sh)
config/sketchybar/
  sketchybarrc                    bar layout
  colors.sh                       THE palette — bar, popups and borders
  variables.sh                    bar height, offsets, fonts, paddings
  items/                          item definitions
  plugins/                        the scripts behind them
```

`colors.sh` is the single source of truth for colour. `bordersrc` sources it,
so recolouring the bar recolours the window borders too.

## cmd+enter — new terminal window

`cmd-enter` opens a new Warp window **on the workspace you are currently on**
(the Omarchy `Super+Enter` habit), via
`config/aerospace/scripts/new-warp-window.sh`.

It works by activating Warp and sending `Cmd+N`, because Warp offers no other
way in: the `warp://action/new_window` deep link is accepted and ignored,
AppleScript `make new window` fails with `-2710` (no `NSAppleScriptEnabled`),
the bundled `oz` CLI only drives the agent, and `open -n -a Warp` starts a
whole second Warp instance on every press. Activating Warp focuses its existing
window — possibly on another workspace, dragging focus along — so the script
records the workspace first and moves the new window back.

Two requirements:

- **`/usr/bin/osascript` needs Accessibility** (System Settings > Privacy &
  Security > Accessibility), or the keystroke is silently dropped.
- **It captures `Cmd+Return` globally.** Apps that use it to send (Slack,
  GitHub, Jira) no longer receive it. Change the binding to `alt-enter` in
  `aerospace.toml` to get it back — `alt` is otherwise unused.

## Machine-specific values

Two things are tuned per machine and will likely need adjusting:

**1. `gaps.outer.top` in `aerospace.toml`.** SketchyBar draws from the physical
top of the screen; AeroSpace measures `outer.top` from the display's *usable*
area. On a notched MacBook the usable area already starts below the notch, so
the built-in display needs a **smaller** value — by exactly that inset:

```
outer.top = BAR_Y_OFFSET + BAR_HEIGHT + desired_gap - display_top_inset
```

`install.sh` prints the real inset for each display. Note it also changes
depending on whether the built-in is the *main* display (menu bar present) or a
secondary one.

**2. Monitor names.** The per-monitor rule matches `[Bb]uilt-[Ii]n`. A
non-matching pattern falls back silently to the default value, so if the gap
looks wrong on one display, check the name with `aerospace list-monitors`.

## Notable deviations from upstream

- No pywal. `colors.sh` holds a static palette; upstream generated it.
- `cpu`/`memory`/`network` click actions open **Activity Monitor** and Wi-Fi
  settings. Upstream launched `btop` in `kitty`, sized with `xdpyinfo` — an X11
  tool that does not exist on macOS, so those clicks did nothing.
- Added a **Bluetooth picker** (`items/bluetooth.sh`, `plugins/bluetooth.sh`):
  device list grouped by connected/other, click to connect or disconnect.
  Needs `blueutil`.
- `volume.sh` rewritten: one `osascript` launch per action instead of six
  (~1.4s → ~0.2s per mute), and it toggles the mute flag rather than zeroing
  the volume and restoring it from a temp file.
- `workspace_manager.sh` guards against AeroSpace not answering (which used to
  wipe every workspace item on wake) and serialises overlapping runs.

## Requirements

Installed by `install.sh`:

- `felixkratz/formulae/sketchybar`, `felixkratz/formulae/borders`
- `nikitabobko/tap/aerospace` (cask)
- `blueutil` — Bluetooth picker
- `font-jetbrains-mono-nerd-font` (cask) — the bar's glyphs
- `jq` — used by several plugins (macOS ships one at `/usr/bin/jq`)
- `raycast` (cask) — launcher
