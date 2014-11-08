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

SLOW_STEPS=0
SELF_VERSION=0.1.0
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
    sleep ${SLOW_STEPS}
}

# Output title level 1
function out_title
{
    tput setaf 2
    echo
    echo "#"
    echo "#"
    for line in "$@"; do
        echo "# ${line}" | tr '[:lower:]' '[:upper:]'
    done
    echo "#"
    echo "#"
    echo
    tput sgr0
    sleep ${SLOW_STEPS}
}

# Output title level 2 (sub-title)
function out_subtitle
{
    tput setaf 6
    echo
    echo "#"
    for line in "$@"; do
        echo "# ${line}"
    done
    echo "#"
    echo
    tput sgr0
    sleep ${SLOW_STEPS}
}

# Output error
function out_error
{
    tput setaf 1
    echo
    echo "#"
    echo "# Error:"
    for line in "$@"; do
        echo "# ${line}"
    done
    echo "#"
    echo "#"
    echo
    tput sgr0
    sleep ${SLOW_STEPS}
}

#
# Output welcome message
#
out_welcome \
    "Scribe Custom Nginx Build v${SELF_VERSION}" \
    "" \
    "Author  : Rob Frawley 2nd <rfrawley@scribenet.com>" \
    "License : MIT License (2-clause)"

#
# Cleanup
#

out_title "Handling cleanup"

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

out_title "Apt Config"
out_subtitle "Inserting http://ppa.launchpad.net/nginx/development/ubuntu" "into /etc/apt/sources.list.d/nginx-development-trusty.list"
sudo su -c 'echo -e "deb http://ppa.launchpad.net/nginx/development/ubuntu trusty main\ndeb-src http://ppa.launchpad.net/nginx/development/ubuntu trusty main" > /etc/apt/sources.list.d/nginx-development-trusty.list'

out_subtitle "Running apt-get update"
sudo apt-get update

out_subtitle "Installing apt dependencies"
sudo apt-get -y install ${APT_DEPENDS}


#
# Setup and get Nginx source
#

out_title "Nginx Source"
out_subtitle "Getting Nginx source files using apt-get source \"nginx\"."
mkdir -p "${DIR_BUILD}" && cd "${DIR_BUILD}"
apt-get source nginx

#
# Install scribe debian install/lintian-overrides/postinst/prerm files
#

out_title "Applying Scribe changes to base config"

cd "${DIR_ROOT}"
for new_file in "${NEW_FILES[@]}"; do
    out_subtitle "Installing new file:" "@ ${DIR_NGINX}/${new_file}"
    cp "${new_file}" "${DIR_NGINX}/${new_file}"
done

mkdir -p "${DIR_SELF_PATCHES}"
for patch_file in "${PATCH_FILES[@]}"; do
    out_subtitle "Creating patch:" "  for ${DIR_NGINX}/${patch_file}" "  from ${DIR_ROOT}/${patch_file}" "  at ${DIR_SELF_PATCHES}/${patch_file_nodir}" "  then applying patch"
    patch_file_nodir="$(echo $patch_file | tr / _)"
    diff "${DIR_NGINX}/${patch_file}" "${patch_file}" > "${DIR_SELF_PATCHES}/${patch_file_nodir}" || diff_ret=$? && true
    if [ "${diff_ret}" != "1" ]; then
        out_error "Could not create diff for ${DIR_SELF_PATCHES}/${patch_file_nodir}"
        exit
    fi
    patch "${DIR_NGINX}/${patch_file}" < "${DIR_SELF_PATCHES}/${patch_file_nodir}"
done

#
# Handle Git Modules
#

out_title "Fetching third-party modules via Git"

for item_i in "${!MOD_GIT_NAME[@]}"; do

    item_version_git="${MOD_GIT_VERSION[$item_i]}"
    item_name_git="${MOD_GIT_NAME[$item_i]}"
    item_path_git="https://github.com/${item_name_git}.git"
    item_path_file="$(echo ${item_name_git} | tr / _)"

    out_subtitle "Module: ${item_name_git}" "Git   : ${item_path_git}" "Vers  : ${item_version_git}" "Path  : ${item_path_file}"
    cd "${DIR_NGINX_MODULES}"
    git clone "${item_path_git}" "${item_path_file}"
    cd "${item_path_file}"
    git checkout "${item_version_git}"

done

#
# Handle PCRE
#

out_title "PCRE Dependency"

out_subtitle "Getting pcre ${PCRE_VERSION} and extracting."
mkdir -p "${DIR_NGINX_EXTDEPS}" && cd "${DIR_NGINX_EXTDEPS}"
wget -O pcre-${PCRE_VERSION}.tar.bz2 http://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2/download
tar xjf pcre-${PCRE_VERSION}.tar.bz2
mv "pcre-${PCRE_VERSION}" "pcre"
cd "pcre"

out_subtitle "Configuring pcre."
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
# Handle ngx_pagespeed
#

out_title "Module: ngx_pagespeed"

out_subtitle "Getting nginx_pagespeed ${NGX_PAGESPEED_VERSION} and extracting."
cd "${DIR_NGINX_MODULES}"
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NGX_PAGESPEED_VERSION}-beta.zip
unzip release-${NGX_PAGESPEED_VERSION}-beta.zip
mv "ngx_pagespeed-release-${NGX_PAGESPEED_VERSION}-beta" "ngx_pagespeed-release-beta"

out_subtitle "Getting page-speed psol ${NGX_PAGESPEED_VERSION} and extracting."
cd "ngx_pagespeed-release-beta"
wget https://dl.google.com/dl/page-speed/psol/${NGX_PAGESPEED_VERSION}.tar.gz
tar -xzvf ${NGX_PAGESPEED_VERSION}.tar.gz

#
# Handle ngx_pagespeed
#

out_title "Building Nginx!"

cd "${DIR_NGINX}"
sudo dpkg-buildpackage -b

#
# DONE!
#

out_title "Complete!"

out_subtitle "Looking to replace your nginx install with nginx-scribe?" "Run:" "sudo dpkg -r --force-all nginx nginx-common nginx-full nginx-light nginx-extra nginx-scribe" "sudo dpkg -i build/nginx-common_1.7.7-1+trusty0-scribe1_all.deb build/nginx-scribe_1.7.7-1+trusty0-scribe1_amd64.deb"
