#!/bin/bash

# install Ferdium
# https://ferdium.org/download
deb_file=$(find ./installation_files -name 'Ferdium*.deb')

# check if the file exists and only then run installation command
# https://unix.stackexchange.com/a/657087/540273
if [[ -n $deb_file ]]
then
  apt -y install $deb_file
else
  echo "Could not find .deb file for Ferdium,, please download first and put in installation_files folder"
fi
