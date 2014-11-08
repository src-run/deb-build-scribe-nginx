#!/bin/bash

##
## Get Nginx source, modules, and handle compililation dependencies
## @author  Rob Frawley 2nd <rfrawley@scribenet.com>
## @license MIT License
##

#
# Stop on non-zero return value
#

set -e

#
# Configure versions of software to use
#

NGINX_VERSION=1.7.7
PCRE_VERSION=8.36
NGX_PAGESPEED_VERSION=1.9.32.2
APT_DEPENDS="dpkg-dev build-essential zlib1g-dev libpcre3 libpcre3-dev unzip perl libreadline-dev libssl-dev libexpat-dev libbz2-dev"

#
# Runtime config
#

UBUNTU_VERSION=14.04
SLOW_STEPS_WELCOME=10
SLOW_STEPS_LEVEL1=4
SLOW_STEPS_LEVEL2=2
SELF_VERSION=0.1.0
APT_DEPENDS_RUNTIME=""
DIR_ROOT="$(pwd)"
DIR_SELF_DEBIAN="${DIR_ROOT}/debian"
DIR_SELF_PATCHES="${DIR_ROOT}/patches"
DIR_BUILD="${DIR_ROOT}/build"
DIR_NGINX="${DIR_BUILD}/nginx-${NGINX_VERSION}"
DIR_NGINX_DEBIAN="${DIR_NGINX}/debian"
DIR_NGINX_MODULES="${DIR_NGINX_DEBIAN}/modules"
DIR_NGINX_EXTDEPS="${DIR_NGINX_DEBIAN}/extdeps"
MOD_GIT_NAME=(
    "openresty/headers-more-nginx-module"
    "openresty/set-misc-nginx-module"
    "openresty/array-var-nginx-module"
    "openresty/drizzle-nginx-module"
    "openresty/rds-json-nginx-module"
    "openresty/rds-csv-nginx-module"
    "openresty/memc-nginx-module"
    "openresty/srcache-nginx-module"
)
MOD_GIT_VERSION=(
    "v0.25"
    "v0.26"
    "v0.03"
    "v0.1.7"
    "v0.13"
    "v0.05"
    "v0.15"
    "v0.28"
)
PATCH_FILES=(
    "debian/changelog"
    "debian/control"
    "debian/rules"
)
NEW_FILES=(
    "debian/nginx-scribe.install"
    "debian/nginx-scribe.lintian-overrides"
    "debian/nginx-scribe.postinst"
    "debian/nginx-scribe.prerm"
)

#
# Helpful functions
#

# Output title level 0 (welcome message)
function out_welcome
{
    tput setaf 3
    echo
    echo "##"
    echo "#"
    for line in "$@"; do
        echo "# ${line}"
    done
    echo "#"
    echo "##"
    echo
    tput sgr0
    sleep ${SLOW_STEPS_WELCOME}
}

# Output title level 1
function out_title
{
    tput setaf 2
    echo
    echo "#"
    for line in "$@"; do
        echo "# ${line}" | tr '[:lower:]' '[:upper:]'
    done
    echo "#"
    echo 
    tput sgr0
    sleep ${SLOW_STEPS_LEVEL1}
}

# Output title level 2 (sub-title)
function out_subtitle
{
    tput setaf 6
    for line in "$@"; do
        echo "# ${line}"
    done
    echo
    tput sgr0
    sleep ${SLOW_STEPS_LEVEL2}
}

# Output error
function out_error
{
    tput setaf 1
    echo
    echo "*"
    echo "* ERROR"
    echo "*"
    for line in "$@"; do
        echo "* ${line}"
    done
    echo "*"
    echo
    tput sgr0
    exit 5
}

# Output empty line
function out_empty
{
    echo
}

# Build APT_DEPENDS_RUNTIME list of packages
function build_apt_depends_runtime
{
    for package in "$@"; do
        APT_DEPENDS_RUNTIME="${APT_DEPENDS_RUNTIME} $(apt-cache depends ${package} | grep Depends | sed -nr "s/.*Depends: ([^<]{1}.*)/\1/p" | tr '\n' ' ')"
        APT_DEPENDS_RUNTIME="$(echo ${APT_DEPENDS_RUNTIME} | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/')"
    done
}

#
# Output welcome message
#
clear
out_welcome \
    "Scribe Custom Nginx Build v${SELF_VERSION}" \
    "" \
    "Author    : Rob Frawley 2nd <rfrawley@scribenet.com>" \
    "Copyright : 2014 Scribe Inc." \
    "License   : MIT License (2-clause)" \
    "" \
    "Beginning in ${SLOW_STEPS_WELCOME} seconds. Press ^C to cancel."

#
# Sanity checks
#

out_title "Performing sanity checks"

# This script should not be run as root: it will escalate with sudo as nessissary
if [[ $EUID == 0 ]]; then
    out_error "Do not run this script as root." "It will use sudo to escalate privileges as needed."
else
    out_subtitle "Script not run as root: good." "Sudo will be used to escalate privleges as needed; enter your password as requested."
fi

# Require compatable Ubuntu version
if [ "$(lsb_release -r | cut -f2)" != "${UBUNTU_VERSION}" ]; then
    out_error "This script is only compatable with Ubuntu version ${UBUNTU_VERSION}"
else
    out_subtitle "Compatable version of Ubuntu detected: ${UBUNTU_VERSION}"
fi

#
# Cleanup
#

out_title "Performing cleanup"

if [[ -d "${DIR_BUILD}" || -d "${DIR_SELF_PATCHES}" ]]; then
    out_subtitle "Removing previous build and/or patchs directory."
    sudo rm -fr "${DIR_BUILD}" || true
    rm -fr "${DIR_SELF_PATCHES}" || true
else
    out_subtitle "Nothing to do!"
fi

#
# Handle apt config and dependencies
#

out_title "Configuring system apt"
out_subtitle "Adding source.list entry:" \
    "  Repo -> http://ppa.launchpad.net/nginx/development/ubuntu" \
    "  File -> /etc/apt/sources.list.d/nginx-development-trusty.list"
sudo su -c 'echo -e "deb http://ppa.launchpad.net/nginx/development/ubuntu trusty main\ndeb-src http://ppa.launchpad.net/nginx/development/ubuntu trusty main" > /etc/apt/sources.list.d/nginx-development-trusty.list'

out_subtitle "Updating apt cache"
sudo apt-get update

out_empty
out_subtitle "Installing preset dependencies"
sudo apt-get -y install ${APT_DEPENDS}

out_empty
out_subtitle "Installing build dependencies"
sudo apt-get -y build-dep nginx nginx-light nginx-full nginx-extras nginx-common

#
# Setup and get Nginx source
#

out_title "Retrieving Nginx Source"
out_subtitle "Running \"apt-get source nginx\"."
mkdir -p "${DIR_BUILD}" && cd "${DIR_BUILD}"
apt-get source nginx

#
# Install scribe debian install/lintian-overrides/postinst/prerm files
#
out_title "Installing new files and patching source"

cd "${DIR_ROOT}"
for new_file in "${NEW_FILES[@]}"; do
    out_subtitle "Installing file:" \
        "  From -> ${DIR_ROOT}/${new_file}" \
        "  To   -> ${DIR_NGINX}/${new_file}"
    cp "${new_file}" "${DIR_NGINX}/${new_file}"
done

mkdir -p "${DIR_SELF_PATCHES}"
for patch_file in "${PATCH_FILES[@]}"
do
    patch_file_nodir="$(echo $patch_file | tr / _)"

    out_subtitle "Creating patch:" \
        "  Original -> ${DIR_NGINX}/${patch_file}" \
        "  Amended  -> ${DIR_ROOT}/${patch_file}" \
        "  Patch    -> ${DIR_SELF_PATCHES}/${patch_file_nodir}"
    diff "${DIR_NGINX}/${patch_file}" "${patch_file}" > "${DIR_SELF_PATCHES}/${patch_file_nodir}" || diff_ret=$? && true

    if [ "${diff_ret}" != "1" ]; then
        out_error "Could not create diff for ${DIR_SELF_PATCHES}/${patch_file_nodir}"
    fi

    out_subtitle "Applying patch:" \
        "  File  -> ${DIR_NGINX}/${patch_file}" \
        "  Patch -> ${DIR_SELF_PATCHES}/${patch_file_nodir}"
    patch "${DIR_NGINX}/${patch_file}" < "${DIR_SELF_PATCHES}/${patch_file_nodir}"
done

#
# Handle Git Modules
#

out_title "Retrieving third-party modules"

for item_i in "${!MOD_GIT_NAME[@]}"; do

    item_version_git="${MOD_GIT_VERSION[$item_i]}"
    item_name_git="${MOD_GIT_NAME[$item_i]}"
    item_path_git="https://github.com/${item_name_git}.git"
    item_path_file="$(echo ${item_name_git} | tr / _)"

    out_subtitle "Fetching ${item_name_git}:" \
        "  Git Remote  -> ${item_path_git}" \
        "  Branch/Tag  -> ${item_version_git}" \
        "  Destination -> ${item_path_file}"
    cd "${DIR_NGINX_MODULES}" && \
        git clone "${item_path_git}" "${item_path_file}" && \
        cd "${item_path_file}" && 
        git checkout "${item_version_git}"
    out_empty

done

out_subtitle "Fetching ngx_pagespeed:" \
    "  Remote      -> https://github.com/pagespeed/ngx_pagespeed/archive/release-${NGX_PAGESPEED_VERSION}-beta.zip" \
    "  Version     -> ${NGX_PAGESPEED_VERSION}" \
    "  Destination -> ngx_pagespeed-release-beta"

cd "${DIR_NGINX_MODULES}" && \
    wget "https://github.com/pagespeed/ngx_pagespeed/archive/release-${NGX_PAGESPEED_VERSION}-beta.zip" && \
    unzip "release-${NGX_PAGESPEED_VERSION}-beta.zip" && \
    mv "ngx_pagespeed-release-${NGX_PAGESPEED_VERSION}-beta" "ngx_pagespeed-release-beta"

out_empty
out_subtitle "Fetching ngx_pagespeed_psol:" \
    "  Remote      -> https://dl.google.com/dl/page-speed/psol/${NGX_PAGESPEED_VERSION}.tar.gz" \
    "  Version     -> ${NGX_PAGESPEED_VERSION}" \
    "  Destination -> ngx_pagespeed-release-beta/psol"

cd "ngx_pagespeed-release-beta" && \
    wget https://dl.google.com/dl/page-speed/psol/${NGX_PAGESPEED_VERSION}.tar.gz && \
    tar -xzvf ${NGX_PAGESPEED_VERSION}.tar.gz

#
# Handle PCRE
#

out_title "Retreiving PCRE Source"

out_subtitle "Fetching and configuring pcre:" \
    "  Remote      -> http://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2/download" \
    "  Version     -> ${PCRE_VERSION}" \
    "  Destination -> ${DIR_NGINX_EXTDEPS}/pcre"

mkdir -p "${DIR_NGINX_EXTDEPS}" && \
    cd "${DIR_NGINX_EXTDEPS}" && \
    wget -O "pcre-${PCRE_VERSION}.tar.bz2" "http://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2/download" && \
    tar xjf pcre-${PCRE_VERSION}.tar.bz2 && \
    mv "pcre-${PCRE_VERSION}" "pcre" && \
    cd "pcre"

./configure \
    --prefix=/usr \
    --mandir=/usr/share/man \
    --infodir=/usr/share/info \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --enable-utf8 \
    --enable-unicode-properties \
    --enable-pcre16 \
    --enable-pcre32 \
    --enable-pcregrep-libz \
    --enable-pcregrep-libbz2 \
    --enable-pcretest-libreadline \
    --enable-jit

#
# Handle Nginx compilation
#

out_title "Compiling Nginx"

cd "${DIR_NGINX}" && \
    sudo dpkg-buildpackage -b

#
# DONE!
#

out_title "Packages generated!"

out_subtitle "To replace the standard nginx packages with \"scribe-nginx\", run:" \
    "  sudo dpkg -r --force-all nginx nginx-common nginx-full nginx-light nginx-extra nginx-scribe" \
    "  sudo dpkg -i build/nginx-common_1.7.7-1+trusty0-scribe1_all.deb build/nginx-scribe_1.7.7-1+trusty0-scribe1_amd64.deb" \
    "  sudo service nginx restart" \

