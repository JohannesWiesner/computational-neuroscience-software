#!/bin/bash

# get the path to the latest obsidian .deb file on GitHub
obsidian_url=$(wget -q -O - https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep 'deb"$' | awk -F'"' ' {print $4} ')

# downlod the .deb file to the installation files folder
curl -L $obsidian_url -o ./installation_files/obsidian_latest.deb

# install obsidian using the .deb file
apt install ./installation_files/obsidian_latest.deb
