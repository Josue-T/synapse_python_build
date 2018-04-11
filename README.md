Build script for synapse arm
=============================

This is a part of the project :  https://github.com/YunoHost-Apps/synapse_ynh
This is a script with provide a virtualenv already built for arm arch with all dependance. It improve the time of synapse package installation on slow arch.

The script build_pyenv.sh is used to build the release package.

How to
------

### Prerequist

The build need a really clean environnement with no library in relation with `python-libxml2` so it's recommended to use a chroot. 

### Preparation

- Install the dependance :
```
apt install -y build-essential python2.7-dev libffi-dev python-pip python-setuptools sqlite3 libssl-dev python-virtualenv libjpeg-dev libpq-dev postgresql libgcrypt11-dev libgcrypt20-dev libxml2-dev libxslt1-dev python-lxml zlib1g-dev
```

- Clone the git repository.

- Lauch the build script by this command : `bash build_pyenv.sh`

- If nothing fail you should find a file named `matrix-synapse_x.x.x-bin1_ARCH.tar.gz` in the same dir then your script.

### Troubleshotting

#### lxml build fail :

In my case the solution to solve my issue was to type these both command to have a really clean environnement (IN CHOOT, because it could break a lot of things in production environnement) :
```
apt-get autoremove --purge python-defusedxml libxml2-utils libxml-libxml-perl libxml-namespacesupport-perl docbook-xml libxml2-dev libxml2 pinentry-curses
apt install -y build-essential python2.7-dev libffi-dev python-pip python-setuptools sqlite3 libssl-dev python-virtualenv libjpeg-dev libpq-dev postgresql libgcrypt11-dev libgcrypt20-dev libxml2-dev libxslt1-dev python-lxml zlib1g-dev
```