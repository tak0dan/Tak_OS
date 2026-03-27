# cli.sh — TUI Engine & Visual Output

Provides the full interactive TUI and all visual output primitives used by
the rest of Nixorcist.

---

## TUI Entry Point

```bash
main_menu
```

Opens the arrow-key navigable root menu.  Called by `nixorcist tui` (the default
when no arguments are given to `nixorcist`).

---

## TUI Primitives

### _tui_read_key

Reads a single keypress including multi-byte escape sequences.

Returns one of: `up` `down` `enter` `esc` `space` or the literal character.

### _tui_menu TITLE ITEMS_ARRAY

Displays a scrollable, arrow-key navigable menu.  Returns the index of the
selected item via stdout.

- `↑` / `↓` — move cursor
- `Enter` — select
- `Esc` / `q` — return -1 (go back / cancel)

Separator items (empty string or `──…──`) are skipped during navigation.

### _tui_checklist TITLE ITEMS_ARRAY STATES_ARRAY

Like `_tui_menu` but each item has a toggleable `[+]` / `[-]` / `[ ]` state.

- `Space` — toggle current item
- `Enter` — confirm selection and return

Used by the review screen to let the user mark packages for install/remove.

### _tui_status_bar TEXT

Renders a one-line status bar at the bottom of the terminal.

---

## Flow Handlers

Each TUI menu option has a dedicated `_tui_flow_*` handler:

| Handler | Description |
|---------|-------------|
| `_tui_flow_install` | fzf package picker → stage to TX_ADD |
| `_tui_flow_remove` | fzf picker from current lock → stage to TX_REMOVE |
| `_tui_flow_chant` | free-text input with +/- syntax |
| `_tui_flow_import` | file path input → `import_from_file` |
| `_tui_flow_review` | checklist of all staged changes → confirm → apply |
| `_tui_flow_fetch_index` | depth picker → `build_nix_index` |
| `_tui_flow_gen_only` | `generate_modules` without rebuild |
| `_tui_flow_view_status` | show lock contents and TX state |

State (TX_ADD / TX_REMOVE) is preserved across all flows.  The user can visit
Install, then Remove, then Chant, then go back and change Install — everything
accumulates until **Review & Cast** is confirmed.

---

## Visual Output Primitives

```bash
show_logo                   # ASCII banner (assets/logo.txt or inline)
show_header "Title"         # Box-drawn section header
show_success "msg"          # ✓ green message
show_error   "msg"          # ✗ red message
show_warning "msg"          # ⚠ yellow message
show_info    "msg"          # ℹ blue message
show_item "icon" "msg"      # ○/✓/✗ item line
show_menu                   # Print the CLI help/command list
```

All output goes to stdout.  Colors use ANSI escape codes and are safe to
redirect (codes are only emitted when stdout is a TTY).

---

## Tracing

Nixorcist has a built-in debug tracer that appends to `nixorcist-trace.txt`.

```bash
nixorcist_trace "TAG" "message"
enable_nixorcist_trace      # activates DEBUG trap
```

Set `NIXORCIST_TRACE_ENABLED=0` to disable.
