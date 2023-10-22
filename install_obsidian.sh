#!/bin/bash

# get current users home directory
USER_HOME=$(eval echo ~${SUDO_USER})

# get the path to the latest obsidian .deb file
obsidian_url=$(wget -q -O - https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep 'deb"$' | awk -F'"' ' {print $4} ')

# downlod the .deb file to Downloads folder
curl -L $obsidian_url -o $USER_HOME/Downloads/obsidian_latest.deb

# install obsidian using the .deb file
apt install $USER_HOME/Downloads/obsidian_latest.deb && rm $USER_HOME/Downloads/obsidian_latest.deb
