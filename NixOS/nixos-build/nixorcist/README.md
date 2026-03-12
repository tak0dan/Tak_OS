# nixorcist - The Declarative NixOS Package Sorcerer

```
  ╔═══════════════════════════════════════════════════════╗
  ║           NIXORCIST - Package Sorcery                 ║
  ║  The declarative NixOS package management framework   ║
  ╚═══════════════════════════════════════════════════════╝
```

A beautiful, modular Bash framework for managing NixOS packages declaratively through an interactive transaction-based interface.

## Features

- **Interactive Package Management** - Fuzzy-find and select packages via fzf
- **Attribute Set Expansion** - Automatically expand package namespaces to concrete derivations
- **Transaction Engine** - Stage, preview, and apply package changes atomically
- **Module Generation** - Automatic creation of Nix modules from lock file
- **Visual CLI** - Beautiful ASCII logo, icons, and formatted output
- **Safe Rebuilds** - Staging, validation, and cleanup of NixOS changes
- **Modular Architecture** - Separated concerns with pure bash libraries

## Quick Start

### Installation (Fresh NixOS)

```bash
# Automated setup (recommended)
cd WtfOS/NixOS
sudo bash install.sh

# Or follow manual steps in INSTALL.md
```

### Basic Usage

```bash
# Interactive package transaction
nixorcist transaction

# Generate Nix modules from lock file
nixorcist gen

# Rebuild NixOS system
nixorcist rebuild

# Do everything at once
nixorcist all
```

## Architecture

```
nixorcist/
├── nixorcist.sh           # Main entry point (command dispatcher)
├── lib/
│   ├── cli.sh             # Visual interface components
│   ├── lock.sh            # Package lock & transaction engine
│   ├── utils.sh           # Validation & package resolution
│   ├── gen.sh             # Module generation
│   ├── hub.sh             # Hub file aggregation
│   └── rebuild.sh         # NixOS rebuild pipeline
├── generated/             # Output directory
│   ├── .modules/          # Generated Nix modules (one per package)
│   └── all-packages.nix   # Hub that imports all modules
├── .lock                  # Package lock file
└── cache/                 # Index and performance cache
```

### Module Structure

| Module | Purpose | Key Functions |
|--------|---------|----------------|
| **cli.sh** | Visual output | `show_logo()`, `show_menu()`, `show_header()`, `show_item()` |
| **lock.sh** | Package management engine | `run_transaction_cli()`, `import_from_file()`, `transaction_apply()` |
| **utils.sh** | Validation & resolution | `is_valid_token()`, `resolve_entry_to_packages()`, `is_derivation()` |
| **gen.sh** | Module generation | `generate_modules()`, `purge_all_modules()` |
| **hub.sh** | Hub aggregation | `regenerate_hub()` |
| **rebuild.sh** | System rebuild | `run_rebuild()`, `cleanup_staging()` |

## Commands

```bash
nixorcist help                 # Show help and command menu
nixorcist transaction          # Interactive add/remove/preview
nixorcist select               # Select packages to add
nixorcist import FILE          # Import packages (+/- switches supported)
nixorcist install ARGS         # Arg import wrapper (alias: add)
nixorcist delete ARGS          # Arg delete wrapper (aliases: remove/uninstall/selecte)
nixorcist chant ARGS           # Mixed +/- add/remove in one run
nixorcist gen                  # Generate modules from lock
nixorcist hub                  # Regenerate import hub
nixorcist rebuild              # Rebuild NixOS system
nixorcist all                  # transaction → gen → hub → rebuild
nixorcist purge                # Remove all modules & clear lock
```

## Documentation

Detailed documentation for each module:

### Installation & Setup
- [INSTALL.md](../INSTALL.md) - Complete installation guide with troubleshooting
- [install.sh](../install.sh) - Automated post-fresh-install script

### Module Documentation
- [README_cli.md](README_cli.md) - CLI visual interface
- [README_lock.md](README_lock.md) - Transaction engine & lock management
- [README_utils.md](README_utils.md) - Validation & package utilities
- [README_gen.md](README_gen.md) - Module generation
- [README_hub.md](README_hub.md) - Hub file management
- [README_rebuild.md](README_rebuild.md) - System rebuild pipeline

## Workflow Examples

### Adding Packages

```bash
# Interactive selection
nixorcist transaction
# ❯ fzf selector shows nixpkgs
# Press TAB to select multiple
# Menu: [1] Stage additions [5] Preview [6] Apply

# Or import from file
echo -e "firefox\ngit\nvim" > packages.txt
nixorcist import packages.txt

# Import supports inline mode switches
echo "firefox +git -vim +helix" > mixed.txt
nixorcist import mixed.txt

# Argument wrappers
nixorcist install a b,c,d
nixorcist delete e f
nixorcist chant a b,c,d -e f,+a +f+g h + l - l
```

`import` and `chant` use the same parser semantics:
- default mode is install
- `+` switches to install mode
- `-` switches to remove mode
- switches can appear multiple times, including inline (example: `+f+g`)
- removals are applied after additions (natural delete priority)

### Attribute Set Expansion

Attribute sets (package namespaces) are automatically expanded to their constituent packages:

```bash
# Lock file entry:
eclipses

# Expands to:
eclipses.eclipse-java
eclipses.eclipse-cpp
eclipses.eclipse-sdk
# ... all IDE variants installed as separate modules
```

### Full Pipeline

```bash
# Stage changes, generate modules, aggregate hub, rebuild all
nixorcist all

# Or step-by-step control:
nixorcist transaction   # Stage packages
nixorcist gen          # Generate Nix modules
nixorcist hub          # Create import aggregation
nixorcist rebuild      # Apply to running system
```

## Code of Conduct

### Core Principles

1. **Pure Functions** - Each module encapsulates a single responsibility
2. **Transaction Safety** - Changes never apply until explicitly confirmed
3. **User Feedback** - Every action provides clear visual feedback
4. **Idempotency** - Safe to re-run without side effects
5. **Declarativity** - Lock file is source of truth; everything else is derived

### Bash Style

- Strict mode: `set -euo pipefail`
- Quote variables: `"$var"` not `$var`
- Use array references: `local -n arr=$1`
- Source dependencies explicitly
- Meaningful variable names (no single letters except loops)

## Integration with NixOS

### Configuration Setup

In `/etc/nixos/configuration.nix`:

```nix
imports = [
  ./hardware-configuration.nix
  ./nixorcist/generated/all-packages.nix  # Nixorcist hub
];

nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### Rebuild Process

```
User runs: nixorcist rebuild
           ↓
    Create staging snapshot
           ↓
    Validate with nix-build
           ↓
    Execute rebuild script
           ↓
    Clean up temp files
           ↓
    ✓ System updated
```

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| "flakes is not a known option" | Enable in configuration.nix: `nix.settings.experimental-features = [ "flakes" ];` |
| "Package not found" | Check spelling; run `nixorcist transaction` for fuzzy search |
| "Rebuild failed" | Inspect `.staging/` directory; check `configuration.nix` syntax |
| "Permission denied" | Run nixorcist with sudo: `sudo nixorcist ...` |

For detailed troubleshooting, see [INSTALL.md](../INSTALL.md#troubleshooting).

## Performance

- **Nix evaluation**: Cached via index file (first run ~10s, subsequent immediate)
- **fzf selector**: Instant for <10k packages
- **Module generation**: O(n) where n = lock entries (~100 packages in ~5s)
- **System rebuild**: Depends on complexity (typically 30s-5m)

## System Requirements

- **NixOS** - Any recent version (24.05+)
- **Bash** - Version 4.0+ (array support)
- **Tools**: `fzf`, `nix`, `sed`, `awk`, `grep`
- **Disk**: 5GB free (initial), 1GB for cache
- **Memory**: 2GB minimum (4GB recommended)

## Security

- ✓ All user input validated before processing
- ✓ Tokens checked against safe character whitelist
- ✓ Module generation validates packages via Nix
- ✓ Staging directory used for safe rebuild validation
- ✓ Marked files prevent accidental data loss

## Contributing

To improve nixorcist:

1. Review module-specific documentation
2. Follow bash style guidelines (documented in README_*)
3. Test changes: `bash -n script.sh` (syntax check)
4. Update README if changing function signatures

## File Structure

```
.
├── nixorcist.sh              # Entry point
├── lib/
│   ├── cli.sh               # UI components
│   ├── lock.sh              # Transaction engine
│   ├── utils.sh             # Validation layer
│   ├── gen.sh               # Module generation
│   ├── hub.sh               # Hub creation
│   └── rebuild.sh           # Rebuild pipeline
├── generated/               # Auto-generated
│   ├── .modules/            # Nix modules
│   └── all-packages.nix     # Import hub
├── .lock                    # Package lock (version-controlled)
├── cache/                   # Index cache (ignore in git)
├── README_*.md              # Module documentation
└── ... (config files)
```

## History

- **Phase 1**: Basic package validation and import improvements
- **Phase 2**: Attribute set expansion and transaction engine
- **Phase 3**: Git integration and version control
- **Phase 4**: Complete visual polish with ASCII logo and UI framework
- **Phase 5**: Comprehensive documentation and automated installation

## License

See project root for license information.

## Support

- Check module README files (README_*.md) for detailed function documentation
- Review generated comments in .nix files for tracing
- Inspect staging directory: `/etc/nixos/.staging/`
- Run with `-v` flag for verbose output (where supported)

---

**nixorcist** — *Declarative package management through the arcane arts of Nix*

