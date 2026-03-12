# README_cli.sh - CLI Interface Module

## Purpose
Provides a beautiful command-line interface with ASCII logo, visual feedback functions, and consistent formatting for the nixorcist tool.

## Command Surface

The CLI now exposes these package entry commands:

- `import FILE`: file-based import with `+/-` parser mode switching
- `install|add ARGS...`: argument wrapper over import (temporary file route)
- `delete|uninstall|remove|selecte ARGS...`: delete wrapper over import (temporary file route)
- `chant ARGS...`: mixed add/remove parser flow in one command

Parser notes:
- default mode is install
- `+` switches to install mode
- `-` switches to remove mode
- signs can appear multiple times and inline (example: `+f+g -vim +helix`)

## Structure

```
lib/cli.sh
├── show_logo()           # Displays ASCII art banner
├── show_menu()           # Shows command reference with box drawing
├── show_divider()        # Prints separator line
├── show_header()         # Section header with title
├── show_section()        # Subsection marker
├── show_error()          # Red error message to stderr
├── show_success()        # Green success indicator
├── show_info()           # Info message with icon
└── show_item()          # Formatted list item with icon
```

## Function Reference

### show_logo()
Displays the nixorcist ASCII art banner.
```bash
show_logo
```

### show_menu()
Shows the command reference with decorative borders.
```bash
show_menu
```

### show_divider()
Prints a horizontal line separator.
```bash
show_divider
```

### show_header(title)
Displays a section header with arrow and divider.
```bash
show_header "Transaction Builder"
```

### show_error(message)
Prints an error message to stderr (red).
```bash
show_error "Invalid token: xyz"
```

### show_success(message)
Prints a success message (green checkmark).
```bash
show_success "Lock updated"
```

### show_info(message)
Prints an informational message (info icon).
```bash
show_info "Processing 15 lock entries"
```

### show_item(status, message)
Prints a formatted list item with custom status icon.
```bash
show_item "✓" "Generated: python.nix"
show_item "+" "Staged: nginx [1 package(s)]"
show_item "-" "Scheduled removal: vim"
```

## Code of Conduct

- **No logic**: This is a pure presentation module. Contains no business logic.
- **Indentation**: All output is indented with 2 spaces for terminal hierarchy.
- **Consistency**: All messages use the same format and spacing.
- **Unicode**: Uses box drawing characters (╔═╗║╚╝) and Unicode symbols.
- **Simple functions**: Each function has a single responsibility.

## Integration

This module should be sourced first in nixorcist.sh:
```bash
source "$ROOT/lib/cli.sh"
source "$ROOT/lib/lock.sh"
source "$ROOT/lib/gen.sh"
```

Other modules use these functions to provide visual feedback.
