#!/bin/bash

set -e

# Colors for messages
GREEN='\033[1;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing TUXEDO Control Center...${NC}"

# 1. Download and install TUXEDO keyring
KEYRING_DEB="tuxedo-archive-keyring_2022.04.01~tux_all.deb"
KEYRING_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-archive-keyring/$KEYRING_DEB"

echo -e "${GREEN}Downloading TUXEDO archive keyring...${NC}"
wget -q $KEYRING_URL

echo -e "${GREEN}Installing keyring...${NC}"
sudo dpkg -i $KEYRING_DEB
rm -f $KEYRING_DEB

# 2. Add TUXEDO APT repository
CODENAME=$(lsb_release -cs)
REPO_LINE="deb [signed-by=/usr/share/keyrings/tuxedo-archive-keyring.gpg] https://deb.tuxedocomputers.com/ubuntu/ $CODENAME main"
REPO_FILE="/etc/apt/sources.list.d/tuxedo.list"

echo -e "${GREEN}Adding TUXEDO APT repository for $CODENAME...${NC}"
echo "$REPO_LINE" | sudo tee $REPO_FILE > /dev/null

# 3. Update package list and install packages
echo -e "${GREEN}Updating APT sources...${NC}"
sudo apt update

echo -e "${GREEN}Installing tuxedo-control-center and drivers...${NC}"
sudo apt install -y tuxedo-control-center tuxedo-drivers

echo -e "${GREEN}Installation complete. Please reboot your system to apply changes.${NC}"

