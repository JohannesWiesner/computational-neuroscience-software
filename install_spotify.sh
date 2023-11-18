#!/bin/bash
# Install spotify client https://www.spotify.com/de/download/linux/

# get current users home directory
USER_HOME=$(eval echo ~${SUDO_USER})

cd $USER_HOME/Downloads
curl -sS https://download.spotify.com/debian/pubkey_7A3A762FAFD4A51F.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
echo "deb http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list
apt-get update && apt-get install spotify-client
