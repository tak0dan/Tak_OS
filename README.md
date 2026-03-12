# Tak_OS

```text
				 j        '-,                                                                                              ,-'        j
					'-.        ',                                                                                          ,'        .-'
						|          \                                                                                        /          |
						'-,         \                                                                                      /         ,-'
							 j         .                                                                                    .         j
							 |          .                                                                                  .          |
		 _....._   |       _. :                                                                                  : ._       |   _....._
	 .`       ''-L     .-   |                                                                                  |   -.     L-''       `.
 .`             '.  /  .` |                                                                                  | `.  \  .'             `.
:                 'Y ,`  /\.        ███╗   ██╗██╗██╗  ██╗ ██████╗ ██████╗  ██████╗██╗███████╗████████╗      /\.  `, Y'                 :
|                  / |  :  .\       ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔══██╗██╔════╝██║██╔════╝╚══██╔══╝     /.  :  | \                  |
|                /`  : "    ./      ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██████╔╝██║     ██║███████╗   ██║       \.    " :  `\                |
|      ..,___..-'     '.    /       ██║╚██╗██║██║ ██╔██╗ ██║   ██║██╔══██╗██║     ██║╚════██║   ██║        \    .'     '-..___,..      |
'     _....   ___      .`  /        ██║ ╚████║██║██╔╝ ██╗╚██████╔╝██║  ██║╚██████╗██║███████║   ██║         \  `.      ___   ...._     '
			| | | \_/ |\    /    '-.      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝╚══════╝   ╚═╝       .-'    \    /| \_/ | | |
\     |'| ''    | '--`       |          The Declarative NixOS Package Sorcerer                            |       `--' |    '' |'|     /
 \    | .\      |            |                                                                            |            |      /. |    /
..:...`pd-Y     |..__.....-.-|                                                                            |-.-.....__..|     Y-dp`...:..
					|     \_.T.L.L_|_|_|                                                                            |_|_|_L.L.T._/     |
					|      \''-T.L_|_|_/                                                                            \_|_|_L.T-''/      |
					 \                |                                                                              |                /
						'-._             \                                                                            /             _.-'
								'.._         :                                                                            :         _..'
										''--...__/                                                                            \__...--''
```

## Intention

Tak_OS is built to make NixOS feel comfortable and familiar for users coming from a classic Linux workflow:

- Keep configuration human-readable and file-centric.
- Keep package operations interactive and understandable.
- Keep system state declarative without forcing a flakes-first model.

The project intentionally centers around classic `/etc/nixos` style imports and generated module files, so users can reason about what changed by reading regular Nix files.

## Core Workflow Philosophy (Classic over Flakes)

Tak_OS favors a **classic config workflow**:

- Primary control point is traditional `configuration.nix` imports.
- Package selections are tracked via lock/query files and generated modules.
- Rebuild behavior is designed around standard `nixos-rebuild` usage.
- No requirement to maintain a `flake.nix` as the main project entrypoint.

Compatibility with flake-enabled commands may exist in parts of the tooling, but the design goal is still a familiar, non-flake-first operational model.

## Technical Decisions

### 1) Generated Module Pipeline

Instead of hand-editing every package entry repeatedly, Tak_OS generates structured module outputs from a controlled source of truth. This gives:

- reproducible rebuilds,
- lower risk of config drift,
- simpler review of package changes.

### 2) Indexed Package Discovery

The package index is cached locally to speed up search and selection. The system tracks:

- cache file presence,
- last fetch date,
- cache size/line health.

This allows interactive refresh decisions instead of blind refetching every time.

### 3) Transaction-Based Package Changes

Install/remove actions are staged first, previewed, then applied. This reduces accidental changes and keeps operations explicit.

### 4) Depth-Controlled Index Fetch

Index refresh supports recursive fetch depth control (1–5), allowing faster lightweight fetches or deeper cataloging when needed.

### 5) User-Controlled Long Operations

During index fetch, the user can cancel with `q/Q` without killing the whole tool session.

## Repository Layout

- `NixOS/install.sh` — automated installation/bootstrap flow.
- `NixOS/INSTALL.md` — detailed install and troubleshooting guide.
- `NixOS/nixos-build/` — project-managed NixOS build/config assets.

## Usage Guide

### 1) Clone and prepare

```bash
git clone <your-repo-url> Tak_OS
cd Tak_OS
```

### 2) Install

Use the project installer:

```bash
cd NixOS
sudo bash install.sh
```

For full manual steps and troubleshooting, follow `NixOS/INSTALL.md`.

### 3) Daily operation model

Typical flow with nixorcist-based tooling:

1. Open transaction mode and stage changes.
2. Preview and confirm package changes.
3. Generate modules/hub as needed.
4. Rebuild system and verify.

### 4) Recommended operator habits

- Use shallow index fetch when speed matters.
- Use deeper fetch when searching broad package trees.
- Review staged changes before apply/rebuild.
- Keep generated files under version control for auditability.

## Possibilities / Roadmap Direction

Tak_OS can grow toward:

- profile-based hardware/workstation presets,
- safer rollback helpers around rebuild boundaries,
- richer diagnostics for package resolution failures,
- optional flake wrappers (without replacing classic workflow).

## Project Goal in One Line

**Make NixOS practical, familiar, and confidently maintainable—without abandoning the classic configuration style.**
