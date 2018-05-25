#!/bin/bash

# Github variable
owner="owner"
repo="repos"
perstok="kkk"

# Chroot config
dir_name="matrix-synapse"
path_to_build="/opt/yunohost/$dir_name"
release_number="1"

#################################################################

if [[ ! "$@" =~ "chroot-yes" ]]
then
	echo "Est vous bien dans un chroot ? [y/n]"
	read a
	if [[ $a != "y" ]]
	then
		echo "Il est fortement conseillé d'être dans un chroot pour faire ces opérations"
		exit 0
	fi
fi

# Upgrade system
apt update
apt dist-upgrade -y
pip2 install --upgrade pip
pip install --upgrade virtualenv

## Get last synapse Version
APP_VERSION=$(curl 'https://api.github.com/repos/matrix-org/synapse/releases/latest' -H 'Host: api.github.com' --compressed | grep -m 1 '"name":' | cut -dv -f2 | cut -d\" -f1)

# Clean environnement
rm -rf $path_to_build
rm -r ~/.cache/pip

# Enable set to be sure that all command don't fail
set -eu

echo "Start build time : $(date)" >> Synapse_build_stat_time.log

# Create new environnement
mkdir -p $path_to_build
virtualenv --no-site-packages --always-copy -p python2.7 $path_to_build
cp activate_virtualenv_synapse $path_to_build/bin/activate

# Go in virtualenv
old_pwd="$PWD"
cd $path_to_build
PS1=""
source bin/activate

# Install source and build binary
#pip install -I --upgrade pip
pip install -I pip==9.0.3 # Fix segfault
pip install -I --upgrade setuptools
pip install -I --upgrade cffi ndg-httpsclient psycopg2 lxml
pip install -I --upgrade https://github.com/matrix-org/synapse/archive/v$APP_VERSION.tar.gz

# Quit virtualenv
deactivate
cd ..

# Build archive of binary
archive_name="matrix-synapse_${APP_VERSION}-$(lsb_release --codename --short)-bin${release_number}_$(uname -m).tar.gz"
tar -czf "$archive_name" "$dir_name"

sha256sumarchive=$(sha256sum "$archive_name" | cut -d' ' -f1)

mv "$archive_name" "$old_pwd"

cd "$old_pwd"

echo "Finish build time : $(date)" >> Synapse_build_stat_time.log
echo "sha256 SUM : $sha256sumarchive"
echo $sha256sumarchive > "SUM_$archive_name"

## Upload Realase

if [[ "$@" =~ "push_release" ]]
then
    ## Make a draft release json with a markdown body
    release='"tag_name": "v'$APP_VERSION'", "target_commitish": "master", "name": "v'$APP_VERSION'", '
    body="Synapse prebuilt bin for synapse_ynh\\n=========\\nPlease refer to main matrix project for the change : https://github.com/matrix-org/synapse/releases\\n\\nSha256sum : $sha256sumarchive"
    body=\"$body\"
    body='"body": '$body', '
    release=$release$body
    release=$release'"draft": true, "prerelease": false'
    release='{'$release'}'
    url="https://api.github.com/repos/$owner/$repo/releases"
    succ=$(curl -H "Authorization: token $perstok" --data "$release" $url)

    ## In case of success, we upload a file
    upload_generic=$(echo "$succ" | grep upload_url)
    if [[ $? -eq 0 ]]; then
        echo "Release created."
    else
        echo "Error creating release!"
        return
    fi

    # $upload_generic is like:
    # "upload_url": "https://uploads.github.com/repos/:owner/:repo/releases/:ID/assets{?name,label}",
    upload_prefix=$(echo $upload_generic | cut -d "\"" -f4 | cut -d "{" -f1)
    upload_file="$upload_prefix?name=$archive_name"
    succ=$(curl -H "Authorization: token $perstok" \
        -H "Content-Type: $(file -b --mime-type $archive_name)" \
        -H "Accept: application/vnd.github.v3+json" \
        --data-binary @$archive_name $upload_file)

    download=$(echo "$succ" | egrep -o "browser_download_url.+?")  
    if [[ $? -eq 0 ]]; then
        echo $download | cut -d: -f2,3 | cut -d\" -f2
    else
        echo Upload error!
    fi
fi

exit 0