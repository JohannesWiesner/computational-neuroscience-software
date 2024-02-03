#!/bin/bash
# https://askubuntu.com/a/510063

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P ./installation_files/
apt -y install ./installation_files/google-chrome-stable_current_amd64.deb
