#!/bin/bash

# install DSI-Studio
# https://dsi-studio.labsolver.org/download.html
install_file=$(find ./deb_files -name 'dsi_studio*.zip')

# check if the file exists and only then run installation command
if [[ -n $install_file ]]
then
  # unzip everything from .zip into folder
  unzip $install_file -d /opt/
  # give everyone reading, writing and execution rights
  chmod -R 777 /opt/dsi-studio
else
  echo "Could not find .zip file for DSI-Studio, please download first and put in deb_files folder"
fi
