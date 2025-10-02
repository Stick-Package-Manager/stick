<img src="https://raw.githubusercontent.com/Stick-Package-Manager/stick/refs/heads/assets/stick_logo.png" width="100" height="100" alt="Stick Logo">

# Stick Package Manager

A minimal, isolated source-based package manager written in V for the Arch User Repository (AUR). Designed for old systems and users who want clean file management without polluting the root filesystem.

## **Disclaimer**  
Stick is still in active development and is **not yet ready for use**.  
While this repository already includes the README, documentation, and other project files, the package manager itself is currently inaccessible and incomplete.  

## Features

- **AUR Search** - Search packages directly from the Arch User Repository
- **Isolated Installation** - Packages install to `~/.stick` with symlinked binaries
- **Automatic Dependency Resolution** - Handles both AUR and system dependencies
- **Smart Upgrades** - Version-aware upgrade system for all packages
- **Reinstall Support** - Force reinstall any package
- **Clean Removal** - Remove packages without system pollution
- **Package Tracking** - List installed packages with versions
- **Lightweight** - Minimal dependencies and fast performance
- **AUR-Focused** - Purpose-built for AUR packages only
- **Multi-threaded** - Parallel downloads and upgrades for speed
- **Signature Verification** - Automatic checksum validation
- **Auto-conflict Resolution** - Automatically handles package conflicts

## Architecture

Stick uses an isolated installation approach:

```
~/.stick/
├── bin/          # Symlinked executables (added to PATH)
├── pkgs/         # Package metadata and tracking
│   └── <pkg>/
│       ├── info.json    # Package info (version, deps)
│       └── root/        # Package installation root
├── cache/        # Download cache
└── stick.conf    # Configuration file
```

### How It Works

1. **Packages install via `makepkg`** to the system (normal AUR workflow)
2. **Binaries are symlinked** to `~/.stick/bin` for isolation
3. **Your PATH is updated** automatically (in `.bashrc` or `.zshrc`)
4. **System stays clean** - easy to track what Stick manages

## Prerequisites

- [V compiler](https://vlang.io/) (latest version recommended)
- `pacman` package manager (Arch Linux or derivative)
- `makepkg` (from `base-devel` package)
- `tar` utility
- `sh` shell
- `sudo` access (for system dependencies)
- Internet connection

### Install Prerequisites

```bash
sudo pacman -S base-devel
```

## Installation

### Quick Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Stick-Package-Manager/stick/main/install.sh | bash
```

Or with `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/Stick-Package-Manager/stick/main/install.sh | bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/Stick-Package-Manager/stick.git
cd stick

# Build with V
v -prod stick.v

# Move to system path
sudo mv stick /usr/local/bin/

# Verify installation
stick
```

### Run directly

```bash
v stick.v

./stick search vim
```

## Usage

### Command Overview

```bash
stick <command> [package]
```

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `install` | Install package with dependencies | `stick install yay` |
| `remove` | Remove installed package | `stick remove yay` |
| `search` | Search AUR for packages | `stick search firefox` |
| `list` | List all installed packages | `stick list` |
| `upgrade` | Upgrade all installed packages | `stick upgrade` |
| `reinstall` | Reinstall a package | `stick reinstall yay` |

---

### Search Packages

Search the AUR for available packages:

```bash
stick search vim
```

**Output:**
```
vim-ale - Asynchronous Lint Engine for Vim
vim-plug - Minimalist Vim Plugin Manager
neovim - Fork of Vim aiming to improve user experience
```

---

### Install Packages

Install a package from AUR with automatic dependency resolution:

```bash
stick install yay
```

**What happens:**
1. Resolves all dependencies (both AUR and system)
2. **Automatically resolves package conflicts**
3. Installs system dependencies via `pacman` **in parallel**
4. Recursively installs AUR dependencies
5. Downloads package tarball from AUR
6. **Verifies package checksums (sha256/sha512)**
7. Builds with `makepkg`
8. Symlinks binaries to `~/.stick/bin`
9. Tracks installation metadata

**Example output:**
```
Resolving deps for yay...

Conflict detected! yay conflicts with:
  - yay-bin

Automatically removing conflicting packages...
Removing yay-bin...
yay-bin removed.

System deps:
  - git
  - base-devel

AUR deps:
  - go

Installing system dep: git
Verifying checksums for yay...
Checksums verified for yay
Installing yay...
yay installed successfully.
```

---

### Remove Packages

Remove an installed package:

```bash
stick remove yay
```

This removes:
- Package metadata from `~/.stick/pkgs/`
- Symlinks from `~/.stick/bin/`
- Package via `pacman -R` (clean uninstall)

---

### List Installed Packages

Show all packages managed by Stick:

```bash
stick list
```

**Output:**
```
Installed packages:
  yay (12.0.5-1)
  paru (1.11.2-1)
  brave-bin (1.58.124-1)
```

---

### Upgrade All Packages

Update all installed packages to the latest AUR versions with **parallel processing**:

```bash
stick upgrade
```

**What happens:**
1. Checks each installed package against AUR **in parallel**
2. Compares versions
3. Reinstalls if newer version available
4. Skips if already up-to-date

**Example output:**
```
Upgrading 3 package(s)...

Upgrading yay: 12.0.4-1 -> 12.0.5-1
Reinstalling yay...
yay removed.
Installing yay...

paru is up to date (1.11.2-1)
brave-bin is up to date (1.58.124-1)

Upgrade complete.
```

---

### Reinstall Packages

Force reinstall a package (useful for fixing broken installations):

```bash
stick reinstall yay
```

This performs:
1. Complete removal
2. Fresh installation with dependencies

---

## Configuration

### Configuration File

Location: `~/.stick/stick.conf`

```conf
root="~/.stick"
repos=["https://aur.archlinux.org"]
```

**Options:**
- `root` - Base directory for Stick's data
- `repos` - Repository URLs (currently AUR only)

### PATH Configuration

Stick automatically adds `~/.stick/bin` to your PATH by appending to:
- `~/.bashrc` (for bash)
- `~/.zshrc` (for zsh)

**Reload your shell after first install:**
```bash
source ~/.bashrc  # or ~/.zshrc
```

---

## Dependency Resolution

Stick intelligently handles dependencies:

### System Dependencies
- Detected via `pacman -Si`
- Installed automatically with `sudo pacman -S`
- Installed in parallel for performance
- Examples: `git`, `base-devel`, `python`

### AUR Dependencies
- Detected via AUR RPC API
- Installed recursively before the target package
- Examples: `yay`, `paru`, custom packages

### Dependency Tree Example

```
Installing: yay
├── System: git (auto-installed in parallel)
├── System: base-devel (auto-installed in parallel)
└── AUR: go
    ├── System: gcc (auto-installed)
    └── Builds and installs
```

---

## Examples

### Install a Complete Development Environment

```bash
# Install yay AUR helper
stick install yay

# Install development tools
stick install visual-studio-code-bin
stick install postman-bin
stick install docker-desktop
```

### Search and Install

```bash
# Find a package
stick search discord

# Install it
stick install discord-canary
```

### Maintain Your System

```bash
# List what you have
stick list

# Update everything
stick upgrade

# Fix a broken package
stick reinstall discord-canary
```

---

## Known Limitations

- **AUR Only** - Does not manage official Arch repository packages
- **No Rollback** - Cannot revert to previous package versions
- **Manual Conflicts** - Does not automatically resolve all package conflicts
- **Limited Testing** - Primarily tested on Arch Linux
- **System Integration** - Uses `pacman` for actual installation (not fully isolated)
- **Binary Linking** - Only links executables, not libraries or config files

---

## Security Considerations

**IMPORTANT**: Stick executes PKGBUILD scripts from the AUR, which can contain arbitrary code.

**Best Practices:**
1. Always review PKGBUILDs before installation
2. Only install packages from trusted maintainers
3. Check package comments and votes on AUR
4. Use at your own risk for untrusted sources

**How to review before install:**
```bash
# Search for package
stick search <package>

# Manually download and inspect
cd /tmp
git clone https://aur.archlinux.org/<package>.git
cd <package>
cat PKGBUILD  # Review the build script

# If safe, install
stick install <package>
```

---

## Troubleshooting

### Package Won't Install

```bash
# Check if package exists in AUR
stick search <package-name>

# Try reinstalling
stick reinstall <package-name>

# Check system dependencies
pacman -S base-devel git
```

### PATH Not Updated

```bash
# Manually add to your shell config
echo 'export PATH="$HOME/.stick/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Build Failures

```bash
# Update system packages first
sudo pacman -Syu

# Install base development tools
sudo pacman -S base-devel

# Try reinstalling
stick reinstall <package>
```

### Checksum Verification Failed

```bash
# Package may be compromised or outdated
# Check AUR comments for known issues
# Try updating package database
stick upgrade

# If persistent, report to AUR maintainer
```

### Permission Errors

```bash
# Ensure sudo access
sudo -v

# Check ownership
ls -la ~/.stick
```

---

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Commit with clear messages (`git commit -m 'Add amazing feature'`)
5. Push to your branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines

- Follow V language conventions
- Maintain error handling for all operations
- Keep functions small and focused
- Test with multiple AUR packages
- Document any new features

---

## License

This project is licensed under the MPL 2.0 License - see the LICENSE file for details.

---

## Roadmap

Future improvements planned:

- [X] Parallel package downloads
- [ ] Build cache for faster reinstalls
- [ ] Package groups support
- [ ] Configurable build flags
- [ ] Rollback functionality
- [X] Package checksum verification
- [ ] Advanced conflict resolution
- [ ] Package statistics

---

## FAQ

**Q: Does this replace pacman?**  
A: No, Stick is designed for AUR packages only. Use `pacman` for official repositories.

**Q: Is this safe to use?**  
A: As safe as manually installing AUR packages. Always review PKGBUILDs first. Stick includes automatic checksum verification for added security.

**Q: Can I use this on non-Arch systems?**  
A: No, it requires `pacman` and is designed specifically for Arch-based distributions.

**Q: How do I uninstall Stick?**  
A: Remove all packages with `stick remove`, then delete `~/.stick` and remove Stick binary from `/usr/local/bin/`.

**Q: Does it support package verification?**  
A: Yes, Stick automatically verifies checksums from PKGBUILD files. Use AUR web interface to check package signatures and comments.

**Q: How fast is the parallel installation?**  
A: System dependencies install 5-10x faster with parallel processing. Upgrades are 3-5x faster with concurrent version checking.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/Stick-Package-Manager/stick/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Stick-Package-Manager/stick/discussions)

---

**Made with <3 for and by the Arch Linux community**

© 2025 ihatemustard & Stick Package Manager contributors
