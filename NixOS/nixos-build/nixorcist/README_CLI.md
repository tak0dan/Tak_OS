# README_CLI.sh

## Overview
The CLI module provides visual interface components for nixorcist. It abstracts all user-facing output formatting, making the codebase more maintainable and enabling consistent UI across all commands.

## Command Surface

Current command routes in the main CLI include:

- `import FILE` - file import with `+/-` mode switching
- `install|add ARGS...` - argument wrapper routed through import with temporary file
- `delete|uninstall|remove|selecte ARGS...` - delete wrapper routed through import with temporary file
- `chant ARGS...` - mixed add/remove in one argument stream

Parser behavior for `import` and wrappers:
- default mode is install
- `+` switches to install mode
- `-` switches to remove mode
- signs can be repeated and inline (`+f+g -vim +helix`)

## Location
`lib/cli.sh`

## Functions

### `show_logo()`
Displays the ASCII art nixorcist banner.

**Usage:**
```bash
show_logo
```

**Output:**
Beautiful ASCII logo identifying the tool as "The declarative NixOS package sorcerer"

---

### `show_menu()`
Displays the command reference menu in a framed box format.

**Usage:**
```bash
show_menu
```

**Output:**
Complete list of available commands with descriptions and examples

---

### `show_divider()`
Prints a horizontal divider line for visual separation.

**Usage:**
```bash
show_divider
```

---

### `show_header(title)`
Prints a section header with visual indicator.

**Parameters:**
- `$1` - Title string

**Usage:**
```bash
show_header "Transaction Builder"
```

---

### `show_section(title)`
Prints a section start indicator for grouping.

**Parameters:**
- `$1` - Section title

**Usage:**
```bash
show_section "Processing Packages"
```

---

### `show_error(message)`
Prints an error message with error icon to stderr.

**Parameters:**
- `$1` - Error message

**Usage:**
```bash
show_error "Failed to validate package"
```

---

### `show_success(message)`
Prints a success message with checkmark icon.

**Parameters:**
- `$1` - Success message

**Usage:**
```bash
show_success "Lock updated"
```

---

### `show_info(message)`
Prints an informational message with info icon.

**Parameters:**
- `$1` - Info message

**Usage:**
```bash
show_info "Processing 42 packages"
```

---

### `show_item(status, message)`
Prints a list item with custom status indicator.

**Parameters:**
- `$1` - Status symbol/icon
- `$2` - Item description

**Usage:**
```bash
show_item "✓" "Generated: config.nix"
show_item "-" "Staged: firefox"
show_item "?" "Unresolved: package"
```

---

## Code Style Guidelines

- All output functions should indent with 2 spaces (`  `)
- Use Unicode symbols for visual indicators (✓, ✗, ℹ, ○, etc.)
- Messages should be concise and actionable
- Error messages go to stderr; all others to stdout
- Wrap long output in dividers for visual separation

## Dependencies
- None; pure bash

## Example Integration
```bash
source "$ROOT/lib/cli.sh"

show_header "Building System"
show_info "Starting rebuild process"
show_item "+" "Added: firefox"
show_item "-" "Removed: chromium"
show_divider
show_success "Rebuild complete"
```
