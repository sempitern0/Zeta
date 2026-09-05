🌐 **Read in other languages:** [Español](README_ES.md)

---

# bash-cli-starter

A production-ready, modular template for building robust Bash CLI applications and tools. It comes pre-configured with ShellCheck linting, cross-platform CRLF-to-LF normalization, automated Makefile tasks, and Git pre-commit hooks.

## 🌟 Key Features

- **Modular Architecture**: Built-in separation of concerns (`cli.sh` entry point, `lib/` modules).
- **Automated Quality Checks**: Pre-configured `.shellcheckrc` tailored for library-based Bash projects.
- **Cross-Platform Compatibility**: Automatic line ending conversion (`CRLF` to `LF`) preventing Windows/WSL execution errors (`SC1017`).
- **Git Pre-Commit Hook**: Intercepts `git commit` to lint staged shell scripts automatically.
- **Makefile Automation**: Easy one-command setup for permissions, hook installations, and code linting.
- **Multi-Platform CI Support**: Native GitHub Actions pipeline active by default, with ready-to-use configurations for GitLab, Bitbucket, Azure, and CircleCI.

## 📁 Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── lint.yml         # Active GitHub Actions CI pipeline
├── ci/                      # Pre-built templates for alternative CI providers
│   ├── .gitlab-ci.yml.example
│   ├── azure-pipelines.yml.example
│   ├── bitbucket-pipelines.yml.example
│   └── circleci-config.yml.example
├── .gitattributes      # Forces LF line endings across all OS environments
├── .shellcheckrc       # ShellCheck rules tailored for modular scripts
├── Makefile            # Task automation runner
├── cli.sh              # Main CLI entry point script
├── lib/
│   ├── cli.sh          # Argument parsing and option handlers
│   └── common.sh       # Shared helper functions and system utilities
└── scripts/
    └── pre-commit      # Git pre-commit hook template
```

## 🚀 Getting Started

### Prerequisites

Ensure you have `git`, `make`, and `shellcheck` installed on your system.

- **macOS**: `brew install shellcheck`
- **Ubuntu/Debian**: `sudo apt-get install shellcheck`
- **Windows (PowerShell)**: `winget install koalaman.shellcheck`

### One-Command Setup

Run the setup target to make scripts executable, install the Git pre-commit hook, and verify linting:

```bash
make setup
```

## 🛠️ Usage & Makefile Commands

| Command                   | Description                                                             |
| :------------------------ | :---------------------------------------------------------------------- |
| `make setup`              | Full initial setup: grants permissions, installs hooks, and runs linter |
| `make lint`               | Fixes line endings and runs ShellCheck across all shell files           |
| `make install-hooks`      | Copies the pre-commit script to `.git/hooks/pre-commit`                 |
| `make chmod`              | Grants execution permissions (`+x`) to scripts and hooks                |
| `make install-shellcheck` | Attempts to auto-install ShellCheck using system package managers       |

## 🧪 Pre-commit Hook

Once installed, the pre-commit hook runs automatically whenever you execute `git commit`. It converts line endings to `LF` and verifies all staged `.sh` files with ShellCheck. If any linting errors occur, the commit is blocked until resolved.

## 🔄 Continuous Integration (CI/CD)

Continuous integration is pre-configured out of the box to guarantee parity between local development and cloud verification by running `make lint`.

CI/CD configurations are built directly into the root directory (and `.circleci/`), pre-configured to execute `make lint` across all major platforms. No extra file moving or configuration setup is needed—simply push your repository to your provider of choice:

| Provider                   | Configuration File           | Status                  |
| :------------------------- | :--------------------------- | :---------------------- |
| **🐙 GitHub Actions**      | `.github/workflows/lint.yml` | ✅ Ready out of the box |
| **🦊 GitLab CI**           | `.gitlab-ci.yml`             | ✅ Ready out of the box |
| **🪣 Bitbucket Pipelines** | `bitbucket-pipelines.yml`    | ✅ Ready out of the box |
| **☁️ Azure Pipelines**     | `azure-pipelines.yml`        | ✅ Ready out of the box |
| **⭕ CircleCI**            | `.circleci/config.yml`       | ✅ Ready out of the box |

# How to Extend CLI Arguments (`parse_args` & `show_help`)

This guide explains how to add new flags, options with values, and long options to the argument parser in `lib/cli.sh`.

---

## 1. Overview of `getopts` Mechanics

The argument parser uses Bash's built-in `getopts` combined with custom logic to handle both short (`-o`) and long (`--option`) arguments.

The string passed to `getopts` controls option requirements:

```bash
while getopts "o:c:fvh-:" opt; do
```

- `v`: A letter **without** a colon is a boolean flag (no value required).
- `o:`: A letter **with** a trailing colon requires a value (e.g., `-o <file>`).
- `-:`: Trailing `-:` intercepts long options starting with `--`.

---

## 2. Step-by-Step: Adding a New Short & Long Option

Suppose you want to add a new `--target` / `-t` option that accepts a string parameter, and a `--dry-run` boolean flag.

### Step 1: Declare Default Variables

Define default values at the top of `lib/cli.sh` (or script level):

```bash
TARGET_ENV="production"
DRY_RUN=false
```

### Step 2: Update the `getopts` String

Add `t:` (requires value) to the option string:

```bash
# Before: "o:c:fvh-:"
# After:  "o:c:t:fvh-:"
while getopts "o:c:t:fvh-:" opt; do
```

### Step 3: Handle the Short Flag (`case "$opt"`)

Add the single-letter handler inside the main `case`:

```bash
case "$opt" in
    t) TARGET_ENV="$OPTARG" ;;
    # ...
esac
```

### Step 4: Handle Long Options (`case "${OPTARG}"`)

Add cases for long option syntax under the `-)` section:

```bash
-)
    case "${OPTARG}" in
        # Long boolean flag
        dry-run) DRY_RUN=true ;;

        # Long option with '=' syntax (--target=staging)
        target=*) TARGET_ENV="${OPTARG#*=}" ;;

        # Long option with space syntax (--target staging)
        target)
            TARGET_ENV="${!OPTIND}"
            OPTIND=$((OPTIND + 1))
            ;;

        # ...
    esac
    ;;
```

### Step 5: Update `show_help`

Update your help message output in `lib/cli.sh` to document the new parameters:

```bash
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -o, --output <file>    Specify output file destination
  -c, --config <file>    Path to configuration file
  -t, --target <env>     Set target environment (default: production)
  -f, --force            Force execution without prompt
      --dry-run          Simulate execution without modifying system
  -v, --verbose          Enable verbose logging output
  -h, --help             Show this help message and exit
EOF
}
```

---

## 3. Quick Checklist

When adding a new argument:

1. [ ] Declare a default global variable.
2. [ ] Update `getopts` string (add trailing `:` if it takes a value).
3. [ ] Add short option handler (`t)`).
4. [ ] Add long option handlers (`target=*` and `target)`).
5. [ ] Update `show_help()` output text.
6. [ ] Test with both short and long syntax (`-t dev`, `--target=dev`, `--target dev`).

---

# `lib/common.sh` Utility Reference

The `lib/common.sh` module provides standard utilities for UI output, system detection, file handling, and user interaction.

---

## 1. Logging & Formatting

All message functions format text with ANSI colors and output directly to `STDERR` (`>&2`) to avoid corrupting `STDOUT` pipeline streams.

### Standard Loggers

```bash
msg_info "Loading configuration..."     # [INFO] Cyan
msg_success "Database connected."       # [OK] Green
msg_warn "Disk space is running low."   # [WARN] Yellow
msg_error "Failed to write to file."    # [ERROR] Red
```

### Process Loggers

```bash
msg_search "Scanning for packages..."   # [SEARCH] Purple
msg_exec "Running migration..."         # [EXEC] Blue
msg_download "Fetching source archive..."# [FETCH] Bold Blue
msg_build "Compiling binary..."         # [BUILD] Bold Cyan
msg_skip "File exists, skipping..."     # [SKIP] Gray
msg_debug "OPTIND level: $OPTIND"       # [DEBUG] Gray
```

### Visual Dividers

```bash
print_section "Build Phase"  # Displays "===> Build Phase" in bold white
print_separator             # Prints a 50-character gray line
```

---

## 2. OS & System Detection

### Package Manager & Distribution

- **`detect_package_manager`**: Prints `apt` or `pacman` to `STDOUT`. Returns exit status `1` if neither is found.
- **`detect_distribution`**: Parses `/etc/os-release` or `uname` to identify OS family (`debian`, `arch`, `fedora`, or `macos`).

```bash
distro=$(detect_distribution)
case "$distro" in
    debian) apt-get update ;;
    arch) pacman -Sy ;;
esac
```

### Environment Checks

- **`is_server_environment`**: Returns `0` (true) if headless/server environment, `1` (false) if graphical session (Xorg/Wayland/GDM/SDDM) is detected.
- **`is_wsl`**: Returns `0` if running inside Windows Subsystem for Linux.

```bash
if is_wsl; then
    msg_info "Running under WSL environment."
fi
```

---

## 3. System & File Operations

### Root & Privileges

- **`check_root`**: Enforces root execution. Aborts script execution with exit code `1` if `$EUID` is non-zero.
- **`ensure_sudo_installed`**: Verifies `sudo` is installed; automatically attempts package manager installation if running as root.

### File Manipulation

- **`copy_with_backup <src> <dest> <user>`**: Safely copies a file. If `<dest>` exists, it creates `<dest>.bak` before overwriting. Preserves original backup if `.bak` already exists.

```bash
copy_with_backup "configs/app.conf" "/etc/app.conf" "$SUDO_USER"
```

### Utilities

- **`command_exists <cmd>`**: Returns `0` if command is present in `$PATH`, otherwise `1`.
- **`slugify <string>`**: Converts input string to lower-case, URL-safe slug text.

```bash
clean_name=$(slugify "My Test Project 123!") # Output: "my-test-project-123"
```

---

## 4. UI & User Interaction

### User Prompts

- **`prompt_confirmation <message> [default_choice]`**: Prompts user for `[y/N]` confirmation. Returns `0` for Yes, `1` for No/Cancelled.

```bash
if prompt_confirmation "Overwrite existing configuration?" "N"; then
    # Proceed with write
fi
```

### Progress Bar

- **`show_progress_bar <current> <total> [width]`**: Renders an inline dynamic ASCII progress bar to `STDOUT`.

```bash
total=50
for ((i=1; i<=total; i++)); do
    show_progress_bar "$i" "$total" 30
    sleep 0.05
done
```

## 🤝 Contributing

Contributions are welcome! Please read the [Contributing Guide](CONTRIBUTING.md) before submitting a pull request.

## 🛡️ Security

If you discover a security vulnerability, please review our [Security Policy](SECURITY.md) to report it safely.

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
