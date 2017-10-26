#!/bin/bash

dir_to_build="/opt/yunohost/matrix-synpase"

#################################################################

echo "Est vous bien dans un chroot ? [y/n]"
read $a
if [[ $a != "y" ]]
then
	echo "Il est fortement conseillé d'être dans un chroot pour faire ces opérations"
	exit 0
fi

# Install dependance
apt update
apt dist-upgrade
apt install -y build-essential python2.7-dev libffi-dev python-pip python-setuptools sqlite3 libssl-dev python-virtualenv

pip install --upgrade pip
pip install --upgrade virtualenv

# Clean environnement
rm -rf $dir_to_build

# Create new environnement
mkdir -p $dir_to_build
virtualenv --always-copy -p python2.7 $dir_to_build
cp activate_virtualenv $dir_to_build/bin/activate

# Go in virtualenv
old_pwd="$PWD"
cd $dir_to_build
source bin/activate

# Install source and build binary
pip install --upgrade pip
pip install --upgrade setuptools
pip install --upgrade cffi ndg-httpsclient psycopg2 lxml
pip install --upgrade https://github.com/matrix-org/synapse/tarball/master

# Quit virtualenv
deactivate
cd "$old_pwd"

# Build archive of binary
tar -cf "matrix-synpase-bin.tar.gz" "$dir_to_build"

exit 0