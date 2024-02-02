# the g++ compiler has to be installed because sometimes we have to compile packages from source if they are not available as pip-packages
# for the desired python version
apt install g++

# install micromamba
# https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html#manual-installation
mkdir /opt/micromamba & cd /opt/micromamba
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
export MAMBA_ROOT_PREFIX=~/micromamba  # optional, defaults to ~/micromamba
eval "$(./bin/micromamba shell hook -s posix)"
/bin/micromamba shell init -s bash -p ~/micromamba  # this writes to your .bashrc file






