# Stick - A Simple AUR Package Manager

**Stick** is a minimal, fast, and open-source package manager for Arch Linux that supports AUR packages and handles dependencies automatically.

---

## Features

- Install, remove, search, and list AUR packages.  
- Automatically resolves AUR and system dependencies.  
- Keeps track of installed packages in a local directory.  
- Minimal configuration and easy setup.  
- Written in **V** language.  

---

## Requirements

- Arch Linux (or derivative)  
- pacman for system packages  
- makepkg for building AUR packages  
- Internet connection  

---

## Installation

1. Clone or download the Stick source code.  
2. Compile using V:  
v -o stick main.v  
3. Move the binary to a directory in your PATH, for example:  
sudo mv stick /usr/local/bin/  

---

## Configuration

Stick automatically creates a configuration directory at `~/.stick`.  

It contains:  

- stick.conf - the main configuration file  
- pkgs/ - installed packages  
- cache/ - temporary downloads  

Default configuration:  

`root="~/.stick"  
repos=["https://aur.archlinux.org"]`

---

## Usage

`stick <command> [package]`

### Commands

- `install <package>` - Installs a package with all dependencies  
- `remove <package>` - Removes a previously installed package  
- `search <package>` - Searches the AUR for a package  
- `list` - Lists all installed packages  

### Examples

Install a package:  
`stick install yay`  

Remove a package:  
`stick remove yay`  

Search for a package:  
`stick search neofetch`  

List installed packages:  
`stick list`  

---

## How It Works

1. **Dependency Resolution**: Stick fetches package info from the AUR RPC interface and separates system dependencies (installed via pacman) and AUR dependencies.  

2. **Installation**:  
- System dependencies are installed first using pacman.  
- AUR dependencies are recursively installed.  
- The target package is downloaded, extracted, built with makepkg, and installed.  
- Package info is saved in `~/.stick/pkgs/<package>/info.json`.  

3. **Removal**: Deletes the package directory from `~/.stick/pkgs/`.  

---

## Notes

- Stick does **not** modify system-wide package databases; it only tracks AUR packages in its own directory.  
- System packages are installed via pacman as needed.  
- Requires sudo for installing system dependencies.  
