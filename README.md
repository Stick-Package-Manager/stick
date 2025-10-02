
<img src="https://raw.githubusercontent.com/Stick-Package-Manager/stick/refs/heads/assets/stick_logo.png" width="100" height="100" alt="Stick Logo">
  
# Stick - A Simple AUR Package Manager

**Stick** (**S**tuff **T**hat **I**nstalls **C**ode, **K**inda) is a minimal, fast, and open-source package manager for Arch Linux written in V that supports AUR packages and handles dependencies automatically.

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

## Configuration

Stick automatically creates a configuration directory at `~/.stick`.  

It contains:  

- stick.conf - the main configuration file  
- pkgs/ - installed packages  
- cache/ - temporary downloads  

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

> View on GitHub: https://github.com/Stick-Package-Manager/stick

## THIS IS A WIP
