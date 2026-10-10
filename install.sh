#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOGFILE="/tmp/mt7902_install_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOGFILE"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOGFILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGFILE"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOGFILE"
    echo -e "${RED}Log saved to: ${LOGFILE}${NC}"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        fail "Please run as root: sudo ./install.sh"
    fi
}

check_deps() {
    log "Checking build dependencies..."
    local missing=()
    command -v make  >/dev/null 2>&1 || missing+=(make)
    command -v gcc   >/dev/null 2>&1 || missing+=(gcc)

    local kver
    kver=$(uname -r)
    if [ ! -d "/lib/modules/${kver}/build" ]; then
        missing+=("linux-headers-${kver}")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing: ${missing[*]}"
        log "Attempting to install missing packages..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >> "$LOGFILE" 2>&1
            apt-get install -y build-essential "linux-headers-${kver}" >> "$LOGFILE" 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y make gcc "kernel-devel-${kver}" >> "$LOGFILE" 2>&1
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm base-devel linux-headers >> "$LOGFILE" 2>&1
        else
            fail "Cannot auto-install dependencies. Please install: ${missing[*]}"
        fi
        ok "Dependencies installed"
    else
        ok "All build dependencies present"
    fi
}

unload_conflicting() {
    log "Unloading conflicting modules..."
    for mod in mt7902e mt7921e; do
        if lsmod | grep -q "^${mod} "; then
            rmmod "$mod" 2>/dev/null && ok "Unloaded $mod" || warn "Could not unload $mod"
        fi
    done
}

build_driver() {
    log "Building driver for kernel $(uname -r)..."
    make clean >> "$LOGFILE" 2>&1 || true
    if make -j"$(nproc)" >> "$LOGFILE" 2>&1; then
        ok "Driver built successfully"
    else
        fail "Build failed. Check $LOGFILE for details"
    fi
}

install_driver() {
    log "Installing driver module..."
    make install >> "$LOGFILE" 2>&1
    ok "Driver module installed"
}

install_firmware() {
    log "Installing firmware..."
    make install_fw >> "$LOGFILE" 2>&1
    ok "Firmware installed"
}

load_driver() {
    log "Loading driver..."
    modprobe mt7902e 2>>"$LOGFILE"
    sleep 2
    if lsmod | grep -q "^mt7902e"; then
        ok "Driver loaded"
    else
        fail "Driver failed to load. Check 'dmesg' for details"
    fi
}

verify() {
    log "Verifying installation..."
    local iface
    iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [ -n "$iface" ]; then
        ok "WiFi interface detected: $iface"
    else
        warn "No WiFi interface found yet — a reboot may be needed"
    fi
}

main() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  MT7902 Driver Installer (kernel 6.1x) ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    log "Log file: $LOGFILE"
    log "Kernel: $(uname -r)"

    check_root
    check_deps
    unload_conflicting
    build_driver
    install_driver
    install_firmware
    load_driver
    verify

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation complete!                ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    log "If WiFi doesn't work immediately, reboot your system."
    log "Log saved to: $LOGFILE"
}

main "$@"
