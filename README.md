# shuttle

A portable shell utility for syncing project files to and from a remote machine over SSH, powered by rsync.

`shuttle` is a profile-based rsync wrapper for bidirectional project sync between local and remote environments. It exists to replace per-project ad-hoc upload/download scripts with one consistent command-line tool and a per-project config file. The design is intentionally minimal: pure Bash, config-driven behavior, safe defaults, and no external runtime dependencies beyond rsync + SSH, with portability across macOS and Linux.

## Requirements

- Bash >= 4.2
- rsync >= 3.1
- SSH with key-based authentication configured
- macOS or Linux

Note: macOS ships Bash 3.2 by default. Install a modern Bash with Homebrew (`brew install bash`). zsh support is planned but not currently supported.

## Installation

### 1) From source

```bash
git clone https://github.com/davidecolombo/shuttle.git
cd shuttle
make install
```

This installs to:

- `~/.local/bin`
- `~/.local/lib/shuttle`
- `~/.local/share/shuttle`

Ensure `~/.local/bin` is on your `PATH`.

### 2) Custom prefix

```bash
make install PREFIX=/usr/local
```

Uninstall:

```bash
make uninstall
```

## Quick Start

### 1) Set up global credentials

```bash
make init-config
# Edit ~/.config/shuttle/credentials.env
```

Expected `~/.config/shuttle/credentials.env`:

```bash
REMOTE_HOST = your.remote.host
REMOTE_USER = your_username
SSH_PORT = 22
# SSH_KEY = /path/to/private_key
```

Security requirement: the file must be owned by your user and mode `600`.

```bash
chmod 600 ~/.config/shuttle/credentials.env
```

### 2) Initialize a project

```bash
cd ~/my-project
shuttle init
# Edit .shuttle.conf
```

### 3) Minimal `.shuttle.conf`

```ini
[default]
remote_root = /remote/path/to/my-project
direction = both
exclude = .git/
exclude = .venv/
exclude = __pycache__/
```

### 4) Daily usage

```bash
shuttle up                          # push local changes to remote
shuttle down                        # pull remote changes to local
shuttle --dry-run up                # preview what would transfer
shuttle status                      # summarize pending changes
shuttle --profile output down       # use a named profile
```

## Configuration Reference

### Global credentials: `~/.config/shuttle/credentials.env`

Supported keys:

- `REMOTE_HOST` (required): remote hostname or host alias
- `REMOTE_USER` (required): remote SSH username
- `SSH_PORT` (optional, default `22`): SSH port
- `SSH_KEY` (optional): path to SSH private key

Validation and security:

- File must exist
- Owner UID must match the current user
- Mode must be exactly `0600`
- Parsed as `KEY=VALUE` lines (manual parse; no `source` execution)

### Project config: `.shuttle.conf`

Format: INI-style sections with `[section]` headers.

Rules:

- `[default]` section is required
- You can add named profiles (for example `[output]`, `[bam]`)
- `shuttle --profile <name> ...` selects a profile

Supported keys per profile:

- `remote_root` (string, required): remote directory root for sync
- `local_root` (string, default project root): local directory root
- `direction` (`up`|`down`|`both`, default `both`): allowed transfer direction
- `include` (repeatable string, default none): rsync include patterns
- `exclude` (repeatable string, default none): rsync exclude patterns
- `rsync_flags` (string, default empty): extra rsync flags appended verbatim
- `delete` (`yes`|`no`, default `no`): add `--delete` when `yes`
- `follow_links` (`yes`|`no`, default `no`): when `yes`, rsync dereferences symbolic links and transfers the file they point to (`--copy-links`); when `no`, symlinks are preserved as symlinks on the destination (`--links`)
- `verify` (`yes`|`no`, default `no`): use `--append-verify` instead of partial mode

`include` and `exclude` are repeatable. Shuttle groups all include rules before all exclude rules when building the rsync command, which supports whitelist-style profiles:

```ini
include = /important/
include = /important/*.tsv
exclude = *
```

Exact mixed rsync filter ordering is not currently supported. For complex filter-order semantics, use direct rsync until a future `filter = ...` directive exists.

## Profiles

A common bioinformatics pattern is keeping source code synced both ways, while downloading outputs into a separate profile with large binary exclusions.

```ini
[default]
remote_root = /mnt/das/users_data/colombo/NextEVE
direction = both
exclude = .git/
exclude = .venv/
exclude = __pycache__/
exclude = .DS_Store
rsync_flags = --compress

[output]
remote_root = /mnt/das/users_data/colombo/pop_NextEVE
local_root = /Users/davidecolombo/Desktop/pop_NextEVE
direction = down
exclude = *.bam
exclude = *.bam.bai
exclude = *.fq.gz
```

## Commands Reference

- `init`: creates `.shuttle.conf` in the current directory from the installed template if it does not already exist, and reports where global credentials should be configured.
- `up`: discovers `.shuttle.conf`, loads global credentials + selected profile, validates direction permissions, builds rsync for upload, then executes it.
- `down`: same as `up`, but for download direction.
- `status`: runs an itemized dry-run and prints a summary of files to send/delete.
- `help`: prints command usage, flags, and config paths.
- `version`: prints the current shuttle version.

Global flags:

- `--dry-run`: add rsync dry-run behavior
- `--verbose`: enable debug logging
- `--profile <name>`: select named profile from `.shuttle.conf`
- `--config <path>`: override project config path

## Delete Safety Guard

When `delete = yes` is enabled and the transfer is not running in dry-run mode, `shuttle` displays a warning and requires interactive confirmation before continuing. To proceed, type the basename of the destination directory exactly as prompted.

Dry-run mode (`--dry-run`) bypasses this confirmation prompt so you can safely preview deletions. If standard input is not a terminal, `shuttle` aborts the transfer instead of attempting a destructive delete without confirmation. `shuttle status` never triggers the guard because it always operates as a dry-run summary.

## How It Works

`shuttle` walks upward from the current directory to discover `.shuttle.conf` (similar to how Git finds `.git/`), loads global SSH credentials from `~/.config/shuttle/credentials.env`, merges those values with the selected profile, builds an rsync command, and executes it. Base rsync flags are `--archive`, `--human-readable`, `--info=progress2`, `--partial`, and `--partial-dir=.rsync-partial`; when `verify = yes`, shuttle switches to `--append-verify` mode for safer large-file continuation and integrity verification.

## License

MIT License. See [LICENSE](LICENSE).

## Author

[Davide Colombo](https://github.com/davidecolombo)

## Changelog

### v0.2.0

- Add `follow_links` config option for symlink handling.
- Add destructive-delete safety guard requiring interactive confirmation when `delete = yes`.

### v0.1.0

- Initial release.
