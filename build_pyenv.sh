#!/bin/bash

dir_to_build="/opt/yunohost/matrix-synapse"
release_number="1"

#################################################################

echo "Est vous bien dans un chroot ? [y/n]"
read a
if [[ $a != "y" ]]
then
	echo "Il est fortement conseillé d'être dans un chroot pour faire ces opérations"
	exit 0
fi

# Upgrade system
apt update
apt dist-upgrade -y
pip2 install --upgrade pip
pip install --upgrade virtualenv

# Clean environnement
rm -rf $dir_to_build

# Enable set to be sure that all command don't fail
set -eu

# Create new environnement
mkdir -p $dir_to_build
virtualenv --no-site-packages --always-copy -p python2.7 $dir_to_build
cp activate_virtualenv $dir_to_build/bin/activate

# Go in virtualenv
old_pwd="$PWD"
cd $dir_to_build
PS1=""
source bin/activate

# Install source and build binary
pip install -I --upgrade pip
pip install -I --upgrade setuptools
pip install -I --upgrade cffi ndg-httpsclient psycopg2 lxml
pip install -I --upgrade https://github.com/matrix-org/synapse/tarball/master

matrix_version=$(pip list --format=columns | grep --line-buffered -E "matrix-synapse  *" | sed 's/matrix-synapse *//' |  sed 's/ *$//')
# Quit virtualenv
deactivate
cd "$old_pwd"

# Build archive of binary
archive_name="matrix-synapse_${matrix_version}-bin${release_number}_$(uname -m).tar.gz"
tar -cf "$archive_name" "$dir_to_build"

echo "sha256 SUM :"
sha256sum "$archive_name"

exit 0