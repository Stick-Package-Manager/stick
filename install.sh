#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

STICK_URL="https://raw.githubusercontent.com/Stick-Package-Manager/stick/main/stick.v"
STICK_LITE_URL="https://raw.githubusercontent.com/Stick-Package-Manager/lite/main/stick-lite.v"
STICKFETCH_URL="https://raw.githubusercontent.com/Stick-Package-Manager/stick/main/stickfetch.v"
INSTALL_DIR="/tmp/stick_install_$$"

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${BOLD}Stick Package Manager - Universal Installer${NC}${CYAN}   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗${NC} $1 is not installed."
        return 1
    else
        echo -e "${GREEN}✓${NC} $1 is installed."
        return 0
    fi
}

install_dependencies() {
    echo -e "${BLUE}→${NC} Installing dependencies..."
    echo ""
    
    if ! check_command "pacman"; then
        echo -e "${RED}Error: This installer requires Arch Linux or an Arch-based distribution.${NC}"
        exit 1
    fi
    
    NEED_INSTALL=()
    
    if ! check_command "curl" && ! check_command "wget"; then
        NEED_INSTALL+=("curl")
    fi
    
    if ! check_command "v"; then
        echo -e "${YELLOW}V compiler not found. Will install V...${NC}"
        INSTALL_V=1
    else
        INSTALL_V=0
    fi
    
    if ! check_command "makepkg"; then
        NEED_INSTALL+=("base-devel")
    fi
    
    if [ ${#NEED_INSTALL[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Installing required packages: ${NEED_INSTALL[*]}${NC}"
        sudo pacman -S --noconfirm --needed "${NEED_INSTALL[@]}"
        echo -e "${GREEN}✓${NC} Packages installed."
    fi
    
    if [ $INSTALL_V -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}Installing V compiler...${NC}"
        if command -v curl &> /dev/null; then
            curl -sSL https://raw.githubusercontent.com/vlang/v/master/cmd/tools/install_v.sh | sh
        elif command -v wget &> /dev/null; then
            wget -qO- https://raw.githubusercontent.com/vlang/v/master/cmd/tools/install_v.sh | sh
        fi
        
        export PATH="$HOME/.v:$PATH"
        
        if ! command -v v &> /dev/null; then
            echo -e "${RED}✗${NC} Failed to install V compiler."
            echo -e "${YELLOW}Please install V manually from: https://vlang.io${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} V compiler installed."
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC} All dependencies met!"
    echo ""
}

show_menu() {
    echo -e "${BOLD}${CYAN}Select what to install:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Stick (Full version with all features)"
    echo -e "  ${GREEN}2)${NC} Stick Lite (Minimal version, install/remove only)"
    echo -e "  ${GREEN}3)${NC} Stickfetch (System info display tool)"
    echo -e "  ${GREEN}4)${NC} All (Stick + Stick Lite + Stickfetch)"
    echo -e "  ${GREEN}5)${NC} Stick + Stickfetch (Recommended)"
    echo -e "  ${RED}0)${NC} Cancel installation"
    echo ""
    echo -n -e "${YELLOW}Enter your choice [1-5, 0 to cancel]:${NC} "
    read -r choice
    echo ""
}

download_file() {
    local url=$1
    local output=$2
    
    if command -v curl &> /dev/null; then
        curl -sSL "$url" -o "$output"
    elif command -v wget &> /dev/null; then
        wget -q "$url" -O "$output"
    else
        echo -e "${RED}✗${NC} Neither curl nor wget available."
        return 1
    fi
    
    if [ ! -f "$output" ]; then
        echo -e "${RED}✗${NC} Failed to download file."
        return 1
    fi
    
    return 0
}

compile_and_install() {
    local name=$1
    local source=$2
    local binary=$3
    
    echo -e "${BLUE}→${NC} Compiling ${name}..."
    v -prod "$source" -o "$binary"
    
    if [ ! -f "$binary" ]; then
        echo -e "${RED}✗${NC} Build failed for ${name}."
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} ${name} compiled."
    
    local install_path="/usr/local/bin/$binary"
    if [ -f "$install_path" ]; then
        echo -e "${YELLOW}⚠${NC}  ${name} already installed. Replacing..."
        sudo rm -f "$install_path"
    fi
    
    echo -e "${BLUE}→${NC} Installing ${name} to ${install_path}..."
    sudo mv "$binary" "$install_path"
    sudo chmod +x "$install_path"
    echo -e "${GREEN}✓${NC} ${name} installed successfully."
    echo ""
    
    return 0
}

install_stick() {
    echo -e "${CYAN}${BOLD}Installing Stick (Full Version)${NC}"
    echo ""
    download_file "$STICK_URL" "stick.v" || return 1
    compile_and_install "Stick" "stick.v" "stick" || return 1
}

install_stick_lite() {
    echo -e "${CYAN}${BOLD}Installing Stick Lite (Minimal Version)${NC}"
    echo ""
    download_file "$STICK_LITE_URL" "stick-lite.v" || return 1
    compile_and_install "Stick Lite" "stick-lite.v" "stick-lite" || return 1
}

install_stickfetch() {
    echo -e "${CYAN}${BOLD}Installing Stickfetch${NC}"
    echo ""
    download_file "$STICKFETCH_URL" "stickfetch.v" || return 1
    compile_and_install "Stickfetch" "stickfetch.v" "stickfetch" || return 1
}

show_completion() {
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Installation Complete!               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$INSTALLED_STICK" = "1" ]; then
        echo -e "${BLUE}→${NC} ${BOLD}Stick${NC} installed to: /usr/local/bin/stick"
        echo -e "   ${GREEN}stick install <package>${NC}  - Install packages"
        echo -e "   ${GREEN}stick search <package>${NC}   - Search for packages"
        echo -e "   ${GREEN}stick list${NC}               - List installed packages"
        echo -e "   ${GREEN}stick upgrade${NC}            - Upgrade all packages"
        echo ""
    fi
    
    if [ "$INSTALLED_LITE" = "1" ]; then
        echo -e "${BLUE}→${NC} ${BOLD}Stick Lite${NC} installed to: /usr/local/bin/stick-lite"
        echo -e "   ${GREEN}stick-lite install <pkg>${NC} - Install package"
        echo -e "   ${GREEN}stick-lite remove <pkg>${NC}  - Remove package"
        echo ""
    fi
    
    if [ "$INSTALLED_FETCH" = "1" ]; then
        echo -e "${BLUE}→${NC} ${BOLD}Stickfetch${NC} installed to: /usr/local/bin/stickfetch"
        echo -e "   ${GREEN}stickfetch${NC}               - Display system info"
        echo ""
    fi
    
    echo -e "${YELLOW}Note:${NC} On first use, Stick will add ~/.stick/bin to your PATH."
    echo -e "      You may need to restart your shell or run: ${GREEN}source ~/.bashrc${NC}"
    echo ""
    echo -e "${BLUE}→${NC} Documentation: ${CYAN}https://github.com/Stick-Package-Manager/stick${NC}"
    echo ""
}

install_dependencies

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

show_menu

INSTALLED_STICK=0
INSTALLED_LITE=0
INSTALLED_FETCH=0

case $choice in
    1)
        install_stick && INSTALLED_STICK=1
        ;;
    2)
        install_stick_lite && INSTALLED_LITE=1
        ;;
    3)
        install_stickfetch && INSTALLED_FETCH=1
        ;;
    4)
        install_stick && INSTALLED_STICK=1
        install_stick_lite && INSTALLED_LITE=1
        install_stickfetch && INSTALLED_FETCH=1
        ;;
    5)
        install_stick && INSTALLED_STICK=1
        install_stickfetch && INSTALLED_FETCH=1
        ;;
    0)
        echo -e "${YELLOW}Installation cancelled.${NC}"
        cd /tmp
        rm -rf "$INSTALL_DIR"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Installation cancelled.${NC}"
        cd /tmp
        rm -rf "$INSTALL_DIR"
        exit 1
        ;;
esac

cd /tmp
rm -rf "$INSTALL_DIR"

if [ "$INSTALLED_STICK" = "1" ] || [ "$INSTALLED_LITE" = "1" ] || [ "$INSTALLED_FETCH" = "1" ]; then
    show_completion
else
    echo -e "${RED}No packages were installed.${NC}"
    exit 1
fi
