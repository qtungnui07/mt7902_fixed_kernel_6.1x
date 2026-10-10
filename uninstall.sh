#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo ./uninstall.sh${NC}"
    exit 1
fi

echo -e "${CYAN}Uninstalling MT7902 driver...${NC}"

cd "$(dirname "$0")"

make uninstall 2>/dev/null || true
make uninstall_fw 2>/dev/null || true

echo -e "${GREEN}MT7902 driver uninstalled. Reboot to apply changes.${NC}"
