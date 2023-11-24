#!/bin/bash

# install zoom client
# https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0063458
deb_file=$(find ./deb_files -name 'zoom_*.deb')

# check if the file exists and only then run installation command
# https://unix.stackexchange.com/a/657087/540273
if [[ -n $deb_file ]]
then
  apt -y install $deb_file
else
  echo "Could not find .deb file for zoom client, please download first and put in deb_files folder"
fi
