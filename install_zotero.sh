#!/bin/bash
# FIXME: User has to manually download .tar.bz file first, but it would be nice if we could automatize this

# install zotero
# https://wiki.ubuntuusers.de/Zotero/#Systemweite-Installation-fuer-alle-Benutzer

# extract .tar.bz file into /opt/zotero
# we use a wildcard so it always works with the latest version
# and we use strip components to get rid of the top-level directory
mkdir /opt/zotero
tar -xf ~/Downloads/Zotero-*_linux-x86_64.tar.bz2 --strip-components=1 -C /opt/zotero
bash /opt/zotero/set_launcher_icon
ln -s /opt/zotero/zotero.desktop /usr/share/applications/

# finally, we have to give others read, write and execute rights so zotero can update automatically
chmod -R 707 /opt/zotero

# we also want the default-jre and the libreoffice-java-common packages
# so that we can use the libre office plugin
apt install default-jre
apt install libreoffice-java-common
