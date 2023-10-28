#!/bin/bash
# install MRIcroGL (https://github.com/rordenlab/MRIcroGL#installation, https://www.nitrc.org/plugins/mwiki/index.php/mricrogl:MainPage)

# get current users home directory
USER_HOME=$(eval echo ~${SUDO_USER})

# download file to Downloads folder
curl -fL https://github.com/rordenlab/MRIcroGL/releases/latest/download/MRIcroGL_linux.zip -o $USER_HOME/Downloads/MRIcroGL_linux.zip

# extract to /opt/MRIcroGL
unzip $USER_HOME/Downloads/MRIcroGL_linux.zip -d /opt/
