#!/bin/bash
# install MRIcroGL (https://github.com/rordenlab/MRIcroGL#installation, https://www.nitrc.org/plugins/mwiki/index.php/mricrogl:MainPage)

# download file to installation_files directory
curl -fL https://github.com/rordenlab/MRIcroGL/releases/latest/download/MRIcroGL_linux.zip -o ./installation_files/MRIcroGL_linux.zip

# extract to /opt/MRIcroGL
unzip $USER_HOME/Downloads/MRIcroGL_linux.zip -d /opt/
