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

# Enable set to be sure that all command don't fail
set -eu

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

# Mount proc if it'isnt mouned.
if [[ $(mount) != *"proc on /proc type proc"* ]]
then
	mount -t proc proc /proc
fi

# Upgrade system
apt-get update
apt-get dist-upgrade -y
apt-get install -y build-essential python3-dev libffi-dev python3-pip python3-setuptools sqlite3 libssl-dev python3-venv libjpeg-dev libpq-dev postgresql libgcrypt20-dev libxml2-dev libxslt1-dev python3-lxml zlib1g-dev curl pkg-config

## Get last synapse Version
APP_VERSION=$(curl 'https://api.github.com/repos/element-hq/synapse/releases/latest' -H 'Host: api.github.com' --compressed | grep -m 1 '"tag_name":' | grep -o -P '(\d+\.)*\d+')

# Clean environnement
rm -rf $path_to_build
rm -rf ~/.cache/pip

echo "Start build time : $(date)" >> Synapse_build_stat_time.log

# Install rustup to build crytography
if [ -z $(which rustup) ]; then
    curl -sSf -L https://static.rust-lang.org/rustup.sh | sh -s -- -y --default-toolchain=stable --profile=minimal
else
    rustup update
fi
source $HOME/.cargo/env

# Create new environnement
mkdir -p $path_to_build
python3 -m venv --copies $path_to_build

# Go in virtualenv
old_pwd="$PWD"
pushd $path_to_build
set +u; source bin/activate; set -u

# Install source and build binary
###### Workaroud for jessie
# python3 -m pip install -I --upgrade pip
# python3 -m pip install -I --upgrade pip
######
pip3 install -I --upgrade pip
pip3 install -I --upgrade setuptools wheel
pip3 install -I --upgrade cffi ndg-httpsclient psycopg2 lxml jinja2
pip3 install -I --upgrade matrix-synapse==$APP_VERSION matrix-synapse-ldap3
pip3 freeze > $old_pwd/matrix-synapse_${APP_VERSION}-$(lsb_release --codename --short)-build${release_number}_requirement.txt

# Quit virtualenv
set +u; deactivate; set -u
cd ..

# Build archive of binary
archive_name="matrix-synapse_${APP_VERSION}-$(lsb_release --codename --short)-bin${release_number}_$(uname -m).tar.gz"
tar -czf "$archive_name" "$dir_name"

sha256sumarchive=$(sha256sum "$archive_name" | cut -d' ' -f1)

mv "$archive_name" "$old_pwd"

popd

echo "Finish build time : $(date)" >> Synapse_build_stat_time.log
echo "sha256 SUM : $sha256sumarchive"
echo $sha256sumarchive > "SUM_$archive_name"

## Upload Realase

if [[ "$@" =~ "push_release" ]]
then
    ## Make a draft release json with a markdown body
    release='"tag_name": "v'$APP_VERSION'", "target_commitish": "master", "name": "v'$APP_VERSION'", '
    body="Synapse prebuilt bin for synapse_ynh\\n=========\\nPlease refer to main matrix project for the change : https://github.com/element-hq/synapse/releases\\n\\nSha256sum : $sha256sumarchive"
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

    echo "Start uploading first file"
    i=0
    upload_ok=false
    while [ $i -le 4 ]; do
        i=$((i+1))
        # Download file
        set +e
        succ=$(curl -H "Authorization: token $perstok" \
            -H "Content-Type: $(file -b --mime-type $archive_name)" \
            -H "Accept: application/vnd.github.v3+json" \
            --data-binary @$archive_name $upload_file)
        res=$?
        set -e
        if [ $res -ne 0 ]; then
            echo "Curl upload failled"
            continue
        fi
        echo "Upload done, check result"

        set +eu
        download=$(echo "$succ" | egrep -o "browser_download_url.+?")
        res=$?
        if [ $res -ne 0 ] || [ -z "$download" ]; then
            set -eu
            echo "Result upload error"
            continue
        fi
        set -eu
        echo "$download" | cut -d: -f2,3 | cut -d\" -f2
        echo "Upload OK"
        upload_ok=true
        break
    done

    if ! $upload_ok; then
        echo "Upload completely failed, exit"
        exit 1
    fi
fi

exit 0
