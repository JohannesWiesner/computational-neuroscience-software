#!/bin/bash
# https://ipv6.rs/tutorial/Debian_Latest/draw.io/

apt-get install openjdk-11-jre-headless xvfb xauth && \
wget https://github.com/jgraph/drawio-desktop/releases/download/v26.0.9/drawio-amd64-26.0.9.deb \
-O ./installation_files/draw.io.deb && \
apt-get install ./installation_files/draw.io.deb
