
# install zotero
# https://wiki.ubuntuusers.de/Zotero/#Systemweite-Installation-fuer-alle-Benutzer

# FIXME: User has to manually download .tar.bz file first,
# but it would be nice if we could automatize this

# extract .tar.bz file into /opt/zotero
# we use a wildcard so it always works with the latest version
# and we use strip components to get rid of the top-level directory
sudo mkdir /opt/zotero
sudo tar -xf ~/Downloads/Zotero-*_linux-x86_64.tar.bz2 --strip-components=1 -C /opt/zotero
sudo bash /opt/zotero/set_launcher_icon
sudo ln -s /opt/zotero/zotero.desktop /usr/share/applications/

# we also want the default-jre and the libreoffice-java-common packages
# so that we can use the libre office plugin
sudo apt install default-jre
sudo apt install libreoffice-java-common
