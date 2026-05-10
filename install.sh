#!/usr/bin/env bash

set -e

# =========================
# Colors and formatting
# =========================

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${BLUE}${BOLD}[*]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[+]${RESET} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[-]${RESET} $1"; }

# =========================
# Detect distribution
# =========================

info "Detecting Linux distribution..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
elif [ -f /etc/arch-release ]; then
    DISTRO="arch"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
else
    error "Unknown distribution"
    exit 1
fi

success "Detected distribution: $DISTRO"

# =========================
# Install dependencies
# =========================

info "Installing dependencies..."

case "$DISTRO" in
    arch | manjaro | endeavouros)
        sudo pacman -Sy --needed \
            git curl make perl \
            python python-pip python-virtualenv \
            wget unzip llvm

        if command -v yay &>/dev/null; then
            success "yay found"
            if command -v ldid &>/dev/null; then
                success "ldid already installed"
            else
                info "Installing ldid via yay..."
                yay -S --needed ldid
            fi
        else
            warn "yay not found, skipping ldid install"
            warn "Please install ldid manually: https://github.com/xerub/ldid"
        fi
        ;;

    ubuntu | debian | pop | linuxmint | kali)
        sudo apt-get update
        sudo apt-get install -y \
            git curl make perl \
            python3 python3-pip python3-venv \
            wget unzip llvm
        warn "ldid must be installed manually on Debian/Ubuntu"
        warn "See: https://github.com/xerub/ldid"
        ;;

    fedora)
        sudo dnf install -y \
            git curl make perl \
            python3 python3-pip \
            wget unzip llvm
        warn "ldid must be installed manually on Fedora"
        warn "See: https://github.com/xerub/ldid"
        ;;

    opensuse* | sles)
        sudo zypper install -y \
            git curl make perl \
            python3 python3-pip \
            wget unzip llvm
        warn "ldid must be installed manually on openSUSE"
        warn "See: https://github.com/xerub/ldid"
        ;;

    *)
        error "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

# =========================
# Check required tools
# =========================

info "Checking required tools..."

MISSING=0

for cmd in llvm-install-name-tool ldid python3; do
    if command -v "$cmd" &>/dev/null; then
        success "$cmd found"
    else
        error "$cmd is not installed"
        MISSING=1
    fi
done

if [ $MISSING -eq 1 ]; then
    error "Missing required tools, please install them and re-run"
    exit 1
fi

# =========================
# Check Theos
# =========================

info "Checking Theos..."

if [ ! -d "$HOME/theos" ]; then
    error "Theos is not installed at $HOME/theos"
    error "Install Theos first before running this script (make sure to install the toolchain too)."
    exit 1
fi

export THEOS="$HOME/theos"
success "Theos found at $THEOS"

# =========================
# Python virtual environment
# =========================

info "Setting up Python virtual environment..."

python3 -m venv .venv
source .venv/bin/activate
pip install -q lief

success "Python environment ready"

# =========================
# Build tweak
# =========================

info "Building tweak..."

make

success "Tweak built and signed"

# =========================
# Input: app path
# =========================

echo
read -r -p "$(echo -e "${CYAN}${BOLD}Enter the path to the GeometryDash.app folder:${RESET} ")" APP

BINARY="$APP/GeometryJump"
DYLIB="build/gd120hz.dylib"

if [ ! -f "$BINARY" ]; then
    error "Binary not found at $BINARY"
    exit 1
fi

if [ ! -f "$DYLIB" ]; then
    error "$DYLIB not found, build step may have failed"
    exit 1
fi

# =========================
# Copy dylib into app
# =========================

info "Copying gd120hz.dylib into app..."
cp "$DYLIB" "$APP/gd120hz.dylib"
success "Copied"

# =========================
# Patch binary
# =========================

info "Injecting rpath @executable_path/. ..."
llvm-install-name-tool -add_rpath "@executable_path/." "$BINARY"

info "Injecting dylib @executable_path/gd120hz.dylib ..."
python3 - <<EOF
import lief
b = lief.MachO.parse("$BINARY").at(0)
b.add_library("@executable_path/gd120hz.dylib")
b.write("$BINARY")
EOF

info "Injecting rpath @executable_path/Frameworks ..."
llvm-install-name-tool -add_rpath "@executable_path/Frameworks" "$BINARY"

info "Replacing OpenGLES with ANGLEGLKit..."
llvm-install-name-tool -change \
    /System/Library/Frameworks/OpenGLES.framework/OpenGLES \
    @rpath/ANGLEGLKit.framework/ANGLEGLKit \
    "$BINARY"

success "Binary patched"

# =========================
# Sign
# =========================

info "Signing binary and dylib with ldid..."
ldid -S "$BINARY"
ldid -S "$APP/gd120hz.dylib"
success "Signed"

# =========================
# Done
# =========================

echo
echo -e "${GREEN}${BOLD}Done!${RESET} Re-sign the IPA with a signing method or reinstall the IPA with a sideload method."
echo
