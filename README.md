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

Warp offers no scriptable way in: the `warp://action/new_window` deep link is
accepted and ignored, AppleScript `make new window` fails with `-2710` (no
`NSAppleScriptEnabled`), the bundled `oz` CLI only drives the agent, and
`open -n -a Warp` starts a whole second Warp instance on every press.

So the script clicks **File > New Window** through the Accessibility API. That
takes ~150ms and never brings Warp forward — which matters, because activating
Warp focuses its existing window and drags AeroSpace onto whatever workspace
that window lives on. A fallback to activate-and-send-`Cmd+N` remains in case
the menu layout changes, and the workspace is restored afterwards if focus did
move.

The new window is then given keyboard focus explicitly. Without that it is
created unfocused whenever Warp was not already frontmost, and typing keeps
going to the app you came from.

Roughly 0.45s end to end. Most of that is Warp itself: the menu click returns
in ~150ms but the window does not exist for another ~210ms, and it cannot be
focused before it exists. The script's own overhead is one `osascript` launch
plus two AeroSpace CLI calls — the startup queries are batched into a single
`aerospace eval`, and the workspace-jump check is skipped unless the fallback
path ran, since each CLI invocation costs ~34ms.

Two requirements:

- **`/usr/bin/osascript` needs Accessibility** (System Settings > Privacy &
  Security > Accessibility), or the keystroke is silently dropped.
- **It captures `Cmd+Return` globally.** Apps that use it to send (Slack,
  GitHub, Jira) no longer receive it. Change the binding to `alt-enter` in
  `aerospace.toml` to get it back — plain `alt-enter` types no character.

### Environment leaks

A GUI app keeps the environment of whatever launched it for the life of the
process, and Warp's terminal server hands that environment to every tab it ever
opens. Launch AeroSpace (or Warp) from inside a Claude Code shell once and
`CLAUDE_CODE_CHILD_SESSION=1` sticks around for good, in every window, where
Claude Code disables transcript saving because it thinks it is a nested session.

Both launch points strip the `CLAUDE_*` / `AI_AGENT` markers first —
`open_warp()` in `new-warp-window.sh`, and `no_claude_env` in `install.sh`
(which also wraps the Raycast and `brew services` launches). Keep the two lists
in sync. Stripping only helps at launch: a Warp or AeroSpace process that
already carries the markers has to be quit and reopened to shed them.

## Keybindings — workspaces

| keys | action |
|---|---|
| `ctrl+alt` + `1`…`9` | switch to workspace N |
| `ctrl+alt+shift` + `1`…`9` | move focused window to workspace N |
| `cmd` + `1`…`9` | same, but **fails inside Chromium apps** |
| `cmd+shift` + `1`…`9` | same |

Chromium-based apps — Brave, WhatsApp, Electron apps generally — intercept
`cmd-1`…`8` for their own tab switching *before* AeroSpace's global hotkey sees
it, so `cmd-N` silently does nothing while one of them is focused. `ctrl-alt-N`
is claimed by nothing and always works.

**Why `ctrl+alt` and not plain `alt`** (AeroSpace's upstream default): on the
German keyboard layout Option *is* the character modifier — `alt-l` is `@`,
`alt-5`/`alt-6` are `[` `]`, `alt-8`/`alt-9` are `{` `}`, `alt-7` is `|`,
`alt-n` is `~`, `alt-e` is `€`. Binding plain `alt-*` swallows those characters
system-wide, so typing `@` would jump monitors instead. Ctrl+Option produces no
characters on any macOS layout. On a US layout plain `alt` is fine — drop the
`ctrl-` prefix if that is all you use.

The `cmd-N` bindings are kept because they still work everywhere else, and
inside Chromium `cmd-N` now usefully falls through to tab switching. Delete them
from `aerospace.toml` if you would rather have one way of doing it.

## Keybindings — focus

`cmd` + `h/j/k/l` focuses the window in that direction, and **crosses monitor
edges**. That is not AeroSpace's default: normally focus is confined to the
current workspace, so on a workspace holding a single window the keys do
nothing at all and the only way out is the mouse. The bindings pass
`--boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors`
to lift that.

## Keybindings — monitors

| keys | action |
|---|---|
| `ctrl+alt` + `h/j/k/l` | focus the monitor in that direction |
| `ctrl+alt+shift` + `h/j/k/l` | move the focused **window** to that monitor |
| `cmd+shift+tab` | move the whole **workspace** to the next monitor |

All wrap around. The window moves keep focus on the window you moved
(`--focus-follows-window`) rather than leaving it on the old monitor.

`ctrl+alt` is used for nothing else in this config, so these cannot collide
with the `cmd` bindings, with macOS, or with German-layout Option characters.

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
