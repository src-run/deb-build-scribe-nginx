#!/bin/bash

##
## Get Nginx source, modules, and handle compililation dependencies
## @author  Rob Frawley 2nd <rfrawley@scribenet.com>
## @license MIT License
##

set -e

##
## Configure settings - be careful editing these, you could hurt yourself
##

## Software versions
VER_NGINX=1.7.9
VER_PCRE=8.36
VER_NGX_MOD_PAGESPEED=1.9.32.3

## The GPG key ID to sign the source/binary with, launchpad URL
BUILD_SIGNING_KEY_ID=313E4FB0
BUILD_LAUNCHPAD_URL="scribeinc/nginx"

## Sbuild distribution name (assumes sbuild has been configured per
## instructions at https://wiki.ubuntu.com/SimpleSbuild)
SBUILD_DIST="trusty-amd64-shm"
#SBUILD_DIST="utopic-amd64-shm"

## Mode
## 1=binary and source
## 2=source only for ppa upload
## 3=source only and do ppa upload
## 4=perform test build with sbuild
BUILD_MODE=1

## Local package cache
LOCAL_PACKAGE_CACHE=1

## Action delay
ACTION_DELAY=0

## Strict build dependencies
APT_DEPS_STRICT="sbuild debhelper ubuntu-dev-tools apt-cacher-ng devscripts dpkg-dev build-essential zlib1g-dev libpcre3 libpcre3-dev unzip perl libreadline-dev libssl-dev libexpat-dev libbz2-dev libmemcache-dev libmemcached-dev"

## Automatically populated by inspecting package dependencies at runtime
APT_DEPS_DYNAMIC=""

## Modules to be installed
MOD_GIT_NAME=(
    "alphashack/nginx_graphdat"
)
MOD_GIT_VERSION=(
    "master"
)

## Files to create patches against original source
PATCH_FILES=(
    "debian/changelog"
    "debian/control"
    "debian/rules"
    "debian/tests/control"
    "debian/modules/ngx-fancyindex/ngx_http_fancyindex_module.c"
)

## New files to install within original source
NEW_FILES=(
    "debian/nginx-scribe.install"
    "debian/nginx-scribe.lintian-overrides"
    "debian/nginx-scribe.postinst"
    "debian/nginx-scribe.prerm"
    "debian/source/include-binaries"
    "debian/patches/ngx-http-extended-status-module.patch"
    "debian/patches/series"
)

## Files requiring version string updates
UPDATE_VER_FILES=(
    "debian/rules"
    "debian/source/include-binaries"
)

## Passed arguments to dpkg-buildpackage
OPT_DPKG_BUILDPACKAGE="-F --force-sign -k${BUILD_SIGNING_KEY_ID}"
OPT_SBUILD="-d ${SBUILD_DIST}"

## Output handling
OUT_SLEEP_LEVEL0=4
OUT_SLEEP_LEVEL1=2
OUT_SLEEP_LEVEL2=1
OUT_SLEEP_SUDONOTICE=4

## Disable output delay handlers
if [[ "${ACTION_DELAY}" == "0" ]]; then
    OUT_SLEEP_LEVEL0=0
    OUT_SLEEP_LEVEL1=0
    OUT_SLEEP_LEVEL2=0
    OUT_SLEEP_SUDONOTICE=0
fi

## Directory structure
DIR_ROOT="$(pwd)"
DIR_SELF_DEBIAN="${DIR_ROOT}/debian"
DIR_SELF_PATCHES="${DIR_ROOT}/patches"
DIR_BUILD="${DIR_ROOT}/build"
DIR_NGINX="${DIR_BUILD}/nginx-${VER_NGINX}"
DIR_NGINX_DEBIAN="${DIR_NGINX}/debian"
DIR_NGINX_MODULES="${DIR_NGINX_DEBIAN}/modules"
DIR_NGINX_EXTDEPS="${DIR_NGINX_DEBIAN}/extdeps"

## Required key
KEY_HREF="http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x00A6F0A3C300EE8C"

## Runtime requirements/vars
VER_UBUNTU=(
    "14.04"
    "14.10"
)
NAM_UBUNTU=(
    "trusty"
    "utopic"
)
VER_SELF=0.1.0

##
## Helper functions
##

## Output welcome message (level 0)
function out_welcome
{
    # Set text color to white
    tput setaf 7

    # Output beginning lines
    echo -en "\n##\n#\n"

    # Output each argument passed as a new line
    for out_line in "$@"
    do
        echo "# ${out_line}"
    done

    # Output ending lines
    echo -en "#\n##\n"

    # Reset console colors
    tput sgr0

    # Sleep to allow reading of message
    sleep ${OUT_SLEEP_LEVEL0}
}

## Output title (level 1)
function out_l1
{
    # Stet text color to green
    tput setaf 2

    # Output beginning lines
    echo -en "\n\n#\n"

    # Output each argument passed as a new line
    for line in "$@"
    do
        # Upper entire string
        echo "# ${line}" | tr '[:lower:]' '[:upper:]'
    done

    # Output ending lines
    echo -en "#\n\n"

    # Reset console colors
    tput sgr0

    # Sleep to allow reading of message
    sleep ${OUT_SLEEP_LEVEL1}
}

## Output title level 2 (sub-title)
function out_l2
{
    # Set text color to cyan
    tput setaf 6

    # Output each argument passed as a new line
    for line in "$@"
    do
        echo "# ${line}"
    done

    # Output ending newline
    echo -en "\n"

    # Reset console colors
    tput sgr0

    # Sleep to allow reading of message
    sleep ${OUT_SLEEP_LEVEL2}
}

## Output sudo usage message
function out_sudonotice
{
    # Set text color to yellow
    tput setaf 3

    # Output beginning lines
    echo -en "#\n# Privilege Escalation Notice:\n#\n"

    # Output each argument passed as a new line
    for line in "$@"
    do
        echo "#   Command -> ${line}"
    done

    # Output ending lineline
    echo -en "#\n# Press ^C within ${OUT_SLEEP_SUDONOTICE} seconds to cancel.\n#\n\n"

    # Reset console colors
    tput sgr0

    # Sleep to allow reading of message
    sleep ${OUT_SLEEP_SUDONOTICE}
}

## Output error and exit
function out_error
{
    # Set text color to red
    tput setaf 1

    # Output preceeding lines
    echo -en "\n*\n* ERROR\n*\n"

    # Output each argument passed as a new line
    for line in "$@"
    do
        echo "* ${line}"
    done

    # Output ending lines
    echo -en "*\n\n"

    # Reset console colors
    tput sgr0

    # Exit with non-zero return
    exit 5
}

## Output line (empty or otherwise)
function out_line
{
    # Output passed text or empty line
    if [ -n "${1}" ]
    then
        echo "${1}"
    else
        echo
    fi
}

## Build package dependencies dynamically
function build_apt_depends_runtime
{
    # For each package name passed...
    for package in "$@"
    do
        # Add to deps listing
        # Get list of package dependencies, using apt-cache depends
        # Use grep and sed to get a list of dependencies for package
        # Implode lines into space-separated string
        APT_DEPS_DYNAMIC="${APT_DEPS_DYNAMIC} $(apt-cache depends ${package} | grep Depends | sed -nr "s/.*Depends: ([^<]{1}.*)/\1/p" | tr '\n' ' ')"
        # Remove all consecutive spaces using sed
        APT_DEPS_DYNAMIC="$(echo ${APT_DEPS_DYNAMIC} | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/')"
        # Remove duplicates
        # Split all dependencies into lines
        # Use sort with unique flag to remove duplicates
        # Merge lines back into space-separated string
        APT_DEPS_DYNAMIC="$(echo ${APT_DEPS_DYNAMIC} | tr ' ' "\n" | sort -u | xargs)"
    done
}

##
## Output welcome message
##

## Clear screen
clear

## Output welcome message with name, author, copyright, and license
out_welcome \
    "Scribe Custom Nginx Build v${VER_SELF}" \
    "" \
    "Author    : Rob Frawley 2nd <rfrawley@scribenet.com>" \
    "Copyright : 2014 Scribe Inc." \
    "License   : MIT License (2-clause)" \
    "" \
    "Beginning in ${OUT_SLEEP_LEVEL0} seconds. Press ^C to cancel."

##
## Sanity checks
##

## User output
out_l1 "Pre-flight sanity checks"

## Check if run as root (EUID 0)
if [[ $EUID == 0 ]]
then
    # If run as root, stop and inform the user not to do so, exit
    out_error \
        "For increased security, this script should not be run as root!" \
        "It will use sudo to escalate privileges when needed."
else
    # Good, this script isn't run as root
    out_l2 \
        "This script will use sudo to escalate privileges as required." \
        "Note: This script will provide a warning and chance to exit before running any escalated commands."
fi

## Foreach supported version
VER_BUILD_UBUNTU=0
NAM_BUILD_UBUNTU=0
for VER_UBUNTU_I in "${!VER_UBUNTU[@]}"
do
    if [[ "$(which lsb_release)" && "$(lsb_release -r | cut -f2)" == "${VER_UBUNTU[$VER_UBUNTU_I]}" ]]
    then
        VER_BUILD_UBUNTU="${VER_UBUNTU[$VER_UBUNTU_I]}"
        NAM_BUILD_UBUNTU="${NAM_UBUNTU[$VER_UBUNTU_I]}"
    fi
done

## Require compatable Ubuntu version
if [[ "${VER_BUILD_UBUNTU}" == 0 || "${NAM_BUILD_UBUNTU}" == 0 ]];
then
    # If unsuported enviornment, exit
    out_error \
        "You are running an incompatable version of Linux." \
        "This script can only be run on Ubuntu versions [$(printf " %s" "${VER_UBUNTU[@]}") ]."
else
    # Good, the enviornment passed basic checks
    out_l2 \
        "You are running a compatable version of Linux:" \
        "  Distribution    -> Ubuntu" \
        "" \
        "  Version Name    -> ${NAM_BUILD_UBUNTU}" \
        "  Version Number  -> ${VER_BUILD_UBUNTU}" \
        "" \
        "  Local Pkg Cache -> $(if [[ "${LOCAL_PACKAGE_CACHE}" == 1 ]]; then echo "Enabled"; else echo "Disabled"; fi)" \
        "  Build Type      -> $(if [[ "${BUILD_MODE}" == 1 ]]; then echo "Build Source and Packages"; elif [[ "${BUILD_MODE}" == 2 ]]; then echo "Build Source Only"; elif [[ "${BUILD_MODE}" == 3 ]]; then echo "Build Source and Uploading to Launchpad"; elif [[ "${BUILD_MODE}" == 4 ]]; then echo "Build Source Performing SimpleSBuild"; else echo "Unsuported Build Mode (That isn't good!)"; fi)"
fi

VER_DEB_NGINX="1.7.9-1+${NAM_BUILD_UBUNTU}2"

if [[ "${NAM_BUILD_UBUNTU}" == "trusty" ]]
then
    ## Include original source for trusty builds
    OPT_DEBUILD="-S -sa -k${BUILD_SIGNING_KEY_ID}"
else
    ## Newer builds (sometimes) don't need the source
    OPT_DEBUILD="-S -sa -k${BUILD_SIGNING_KEY_ID}"
fi

##
## Cleanup (from previous builds)
##

## User Output
out_l1 "Pre-flight cleanup"

## Check for previous build folders
if [[ -d "${DIR_BUILD}" || -d "${DIR_SELF_PATCHES}" ]]
then
    # Let the use know befor calling sudo
    out_sudonotice \
        "rm -fr ${DIR_BUILD}" \
        "rm -fr ${DIR_SELF_PATCHES}"

    # Output info to user
    out_l2 \
        "Removing previous build folders:" \
        "  Build Dir   -> ${DIR_BUILD}" \
        "  Patches Dir -> ${DIR_SELF_PATCHES}"

    # Remove build directory, if exists
    sudo rm -fr "${DIR_BUILD}" || true

    # Remove patches directory, if exists
    rm -fr "${DIR_SELF_PATCHES}" || true
else
    # No cleanup required
    out_l2 "No cleanup required."
fi

#
# Handle apt config and dependencies
#

## User output
out_l1 "Configuring system apt"

## Sudo notice
out_sudonotice \
    "sudo su -c 'echo -e 'deb http://ppa.launchpad.net/nginx/development/ubuntu ${NAM_BUILD_UBUNTU} main\ndeb-src http://ppa.launchpad.net/nginx/development/ubuntu ${NAM_BUILD_UBUNTU} main' > /etc/apt/sources.list.d/nginx-development-sources.list'" \
    "wget -qO - "${KEY_HREF}" | sudo apt-key add -" \
    "sudo apt-get update" \
    "sudo apt-get -y install ${APT_DEPS_STRICT}" \
    "sudo apt-get -y build-dep nginx nginx-extras"

## Add required PPA
out_l2 \
    "Adding source.list entry:" \
    "  Repo -> http://ppa.launchpad.net/nginx/development/ubuntu" \
    "  File -> /etc/apt/sources.list.d/nginx-development-sources.list"

## Handle adding required PPA
echo -e "deb http://ppa.launchpad.net/nginx/development/ubuntu ${NAM_BUILD_UBUNTU} main\ndeb-src http://ppa.launchpad.net/nginx/development/ubuntu ${NAM_BUILD_UBUNTU} main" | sudo tee /etc/apt/sources.list.d/nginx-development-sources.list > /dev/null

## Handle add apt key
out_l2 \
    "Adding key:" \
    "  Key Href -> ${KEY_HREF}"
echo -en "${KEY_HREF}: " && wget -qO - "${KEY_HREF}" | sudo apt-key add -

## Handle apt cache update
out_line && out_l2 "Updating apt cache."
sudo apt-get update

## Handle pre-defined dependency instalation
out_line && out_l2 "Installing pre-set strict build dependencies."
sudo apt-get -y install ${APT_DEPS_STRICT}

## Handle dynamic dependency installation
out_line && out_l2 "Installing dynamic build dependencies."
sudo apt-get -y build-dep nginx nginx-extras

##
## SBuild
##

## User output
out_l1 "Local Apt-Cache"

## Add to apt config
out_l2 \
    "Adding apt-config:" \
    "  Apt Cache Config -> echo 'Acquire::http::Proxy "http://127.0.0.1:3142";' | sudo tee /etc/apt/apt.conf.d/01acng"
echo 'Acquire::http::Proxy "http://127.0.0.1:3142";' | sudo tee /etc/apt/apt.conf.d/01acng > /dev/null 2>&1

## User output
out_l1 "Configure Current user for SBuild"
if [[ "$(groups|grep -o sbuild|wc -l)" == "0" ]]; then
    out_l2 \
        "Adding user to group:" \
        "  $USER -> sbuild"
    sudo adduser $USER sbuild
else
    out_l2 \
        "User already configured in group sbuild"
fi

#mkdir -p $HOME/ubuntu/scratch

#sbuild-update --keygen
#sg sbuild
#mk-sbuild "${NAM_BUILD_UBUNTU}"

#sudo sh -c "sed -e 's#]#-shm]#' \
#  -e 's#^\(directory=.*\)#\1\nunion-overlay-directory=/dev/shm/schroot/overlay#' \
#  /etc/schroot/chroot.d/* > /etc/schroot/chroot.d/shm-overlays.conf"

#schroot --list
#sudo mkdir -p /dev/shm/schroot/overlay/
#sudo mount -o remount,size=75% /dev/shm

##
## Setup and get Nginx source
##

## User output
out_l1 "Retrieving Nginx Source"

## Get nginx source via apt-get source
out_l2 "Running \"apt-get source nginx\"."
mkdir -p "${DIR_BUILD}" && cd "${DIR_BUILD}"
apt-get source nginx

## Symlink debian source package to location dpkg-buildpackage can find
out_line && out_l2 \
    "Symlinking Debian source as original:" \
    "  Target      -> nginx_${VER_NGINX}.orig.tar.gz" \
    "  Destination -> nginx_${VER_DEB_NGINX}.orig.tar.gz"
cd "${DIR_BUILD}" &&
    ln -s "nginx_${VER_NGINX}.orig.tar.gz" "nginx_${VER_DEB_NGINX}.orig.tar.gz"

##
## Install scribe debian install/lintian-overrides/postinst/prerm files
##

## User output
out_l1 "Installing new files and patching source"

## Enter root directory
cd "${DIR_ROOT}"

## For each new file to installed in original source package...
for new_file in "${NEW_FILES[@]}"
do
    out_l2 \
        "Installing file:" \
        "  From -> ${DIR_ROOT}/${new_file}" \
        "  To   -> ${DIR_NGINX}/${new_file}"
    cp "${new_file}" "${DIR_NGINX}/${new_file}"
done

## Make patches directory
mkdir -p "${DIR_SELF_PATCHES}"

## Move changelog for specific ubuntu version to correct location
out_l2 \
    "Moving Changelog for Specific Ubuntu Version" \
    "  From -> ${DIR_SELF_PATCHES}/changelog_${NAM_BUILD_UBUNTU}" \
    "  To   -> ${DIR_SELF_PATCHES}/changelog"
cp "${DIR_SELF_DEBIAN}/changelog_${NAM_BUILD_UBUNTU}" "${DIR_SELF_DEBIAN}/changelog"

## Get the scribe build #
VER_SCR_BUILD="$(cat ${DIR_SELF_DEBIAN}/changelog | head -n 1 | grep -oe "scribe[0-9]*")"

## For each file we want to patch against source package...
for patch_file in "${PATCH_FILES[@]}"
do
    # Substitute directory seps for underscores to create filename from path
    patch_file_nodir="$(echo $patch_file | tr / _)"

    # Perform diff
    out_l2 \
        "Creating patch:" \
        "  Original -> ${DIR_NGINX}/${patch_file}" \
        "  Amended  -> ${DIR_ROOT}/${patch_file}" \
        "  Patch    -> ${DIR_SELF_PATCHES}/${patch_file_nodir}"
    diff "${DIR_NGINX}/${patch_file}" "${patch_file}" > "${DIR_SELF_PATCHES}/${patch_file_nodir}" || diff_ret=$? && true

    # Confirm diff completed successfully
    if [ "${diff_ret}" != "1" ]
    then
        # Exit if diff failed
        out_error "Could not create diff for ${DIR_SELF_PATCHES}/${patch_file_nodir}"
    fi

    # Apply patch
    out_l2 \
        "Applying patch:" \
        "  File  -> ${DIR_NGINX}/${patch_file}" \
        "  Patch -> ${DIR_SELF_PATCHES}/${patch_file_nodir}"
    patch "${DIR_NGINX}/${patch_file}" < "${DIR_SELF_PATCHES}/${patch_file_nodir}" > /dev/null 2>&1
done

## Sed to fix s
for update_ver_file in "${UPDATE_VER_FILES[@]}"
do
    out_l2 \
        "Updating versions:" \
        "  File                    -> ${DIR_NGINX}/${update_ver_file}" \
        "  %VER_NGX_MOD_PAGESPEED% -> ${VER_NGX_MOD_PAGESPEED}" \
        "  %VER_PCRE%              -> ${VER_PCRE}"
    sed -i "s,%VER_NGX_MOD_PAGESPEED%,${VER_NGX_MOD_PAGESPEED},g" "${DIR_NGINX}/${update_ver_file}"
    sed -i "s,%VER_PCRE%,${VER_PCRE},g" "${DIR_NGINX}/${update_ver_file}"

done

##
## Handle Git Modules
##

## User ouput
out_l1 "Retrieving Nginx Modules"

## For each requested module...
for item_i in "${!MOD_GIT_NAME[@]}"; do

    # Get git branch/tag defined for package
    item_version_git="${MOD_GIT_VERSION[$item_i]}"

    # Get git relative and absolute path
    item_name_git="${MOD_GIT_NAME[$item_i]}"
    item_path_git="https://github.com/${item_name_git}.git"

    # Create local filesystem dirname from relative path by substituting dir sep for underscore
    item_path_file="$(echo ${item_name_git} | tr / _)"

    # Handle fetching of git source and checkout of branch/tag
    out_l2 \
        "Fetching ${item_name_git}:" \
        "  Git Remote  -> ${item_path_git}" \
        "  Branch/Tag  -> ${item_version_git}" \
        "  Destination -> ${item_path_file}"
    cd "${DIR_NGINX_MODULES}" &&
        git clone "${item_path_git}" "${item_path_file}" &&
        cd "${item_path_file}" &&
        git checkout "${item_version_git}"

    # Perform submodule init for alphashack/nginx_graphdat
    if [[ "${item_name_git}" == "alphashack/nginx_graphdat" ]]; then

        # Init/update submodule
        out_line && out_l2 \
            "Addition src actions for ${item_name_git}:" \
            "  -> git submodule init" \
            "  -> git submodule update"
        cd "${DIR_NGINX_MODULES}" &&
            cd "${item_path_file}" &&
            git submodule init &&
            git submodule update

        # Remove binary test files
        out_line && out_l2 \
            "Cleaning ${item_name_git} source:" \
            "  Removing Dir -> ${DIR_NGINX_MODULES}/${item_path_file}/lib/module_graphdat/msgpack/test/"
        rm -fr "${DIR_NGINX_MODULES}/${item_path_file}/lib/module_graphdat/msgpack/test/"

    fi

    # Output empty line
    out_line

done

## Get Google PageSpeed Nginx module
out_l2 \
    "Fetching ngx_pagespeed:" \
    "  Remote      -> https://github.com/pagespeed/ngx_pagespeed/archive/release-${VER_NGX_MOD_PAGESPEED}-beta.zip" \
    "  Version     -> ${VER_NGX_MOD_PAGESPEED}" \
    "  Destination -> ngx_pagespeed-release-beta"
cd "${DIR_NGINX_MODULES}" &&
    wget "https://github.com/pagespeed/ngx_pagespeed/archive/release-${VER_NGX_MOD_PAGESPEED}-beta.zip" &&
    unzip "release-${VER_NGX_MOD_PAGESPEED}-beta.zip" &&
    mv "ngx_pagespeed-release-${VER_NGX_MOD_PAGESPEED}-beta" "ngx_pagespeed-release-beta" &&
    rm "release-${VER_NGX_MOD_PAGESPEED}-beta.zip"

## Output empty line
out_line

## Get Google PageSpeed PSOL dependency
out_l2 "Fetching ngx_pagespeed_psol:" \
    "  Remote      -> https://dl.google.com/dl/page-speed/psol/${VER_NGX_MOD_PAGESPEED}.tar.gz" \
    "  Version     -> ${VER_NGX_MOD_PAGESPEED}" \
    "  Destination -> ngx_pagespeed-release-beta/${VER_NGX_MOD_PAGESPEED}.tar.gz"
cd "ngx_pagespeed-release-beta" &&
    wget "https://dl.google.com/dl/page-speed/psol/${VER_NGX_MOD_PAGESPEED}.tar.gz"

##
## Handle PCRE
##

## User output
out_l1 "Retreiving PCRE Source"

## Download and extract PCRE source
out_l2 \
    "Fetching PCRE:" \
    "  Remote      -> http://sourceforge.net/projects/pcre/files/pcre/${VER_PCRE}/pcre-${VER_PCRE}.tar.bz2/download" \
    "  Version     -> ${VER_PCRE}" \
    "  Destination -> ${DIR_NGINX_EXTDEPS}/pcre-${VER_PCRE}.tar.bz2"
mkdir -p "${DIR_NGINX_EXTDEPS}" &&
    cd "${DIR_NGINX_EXTDEPS}" &&
    wget -O "pcre-${VER_PCRE}.tar.bz2" "http://sourceforge.net/projects/pcre/files/pcre/${VER_PCRE}/pcre-${VER_PCRE}.tar.bz2/download"

##
## Handle Nginx compilation
##

## User output
out_l1 "Compiling Nginx Packages"

if [[ "${BUILD_MODE}" == 1 ]]
then

  ## Sudo usage warning
  out_sudonotice \
      "sudo dpkg-buildpackage ${OPT_DPKG_BUILDPACKAGE}"

  ## Do it!
  out_l2 \
      "Building source/dist packages as configured:" \
      "  Command -> dpkg-buildpackage ${OPT_DPKG_BUILDPACKAGE}"
  cd "${DIR_NGINX}" && sudo dpkg-buildpackage ${OPT_DPKG_BUILDPACKAGE}

elif [[ "${BUILD_MODE}" == 2 || "${BUILD_MODE}" == 3 ]]
then

  ## Sudo usage warning
  out_sudonotice \
      "sudo debuild ${OPT_DEBUILD}"

  ## Do it!
  out_l2 \
      "Building source as configured:" \
      "  Command -> debuild ${OPT_DEBUILD}"
  cd "${DIR_NGINX}" && debuild ${OPT_DEBUILD}

elif [[ "${BUILD_MODE}" == 4 ]]
then

  ## Do it!
  out_l2 \
      "No need to build; sbuild will handle that for us."

else

    out_error \
        "Invalid build mode of "${BUILD_MODE}". Choose:" \
        "  1 -> Build Source and Packages (for local install)" \
        "  2 -> Build Source Only (for PPA upload)" \
        "  3 -> Build Source Only (and do PPA upload)" \
        "  4 -> Build Source Only (and run SBuild)"

fi

##
## DONE COMPILING!
##

## User output
out_l1 "Handling Post-Compilation Tasks"

## Enter nginx modified source repo
cd "${DIR_NGINX}"
BUILD_VER_FILENAME="$(cat debian/changelog | head -n 1 | grep -oe "${VER_NGINX}\-[0-9]+${NAM_BUILD_UBUNTU}[0-9]-scribe[0-9]*")"

if [[ "${BUILD_MODE}" == 2 ]]
then

    ## User output
    out_l2 \
        "NOT Uploading source files to Launchpad. You can perform this manually via the provided instructions."

    ## Information on pusing to launchpad
    out_l2 \
        "To upload to launchpad execute the following commands:" \
        "  cd ${DIR_BUILD}" \
        "  dput ppa:${BUILD_LAUNCHPAD_URL} nginx_${BUILD_VER_FILENAME}_source.changes"

elif [[ "${BUILD_MODE}" == 3 ]]
then

    ## User output
    out_l2 \
        "Uploading source files to Launchpad. Please wait."

    ## Information on pusing to launchpad
    out_sudonotice \
        "Uploading source to Launchpad:" \
        "cd ${DIR_BUILD}" \
        "dput ppa:${BUILD_LAUNCHPAD_URL} nginx_${BUILD_VER_FILENAME}_source.changes"

    cd "${DIR_BUILD}"
    dput "ppa:${BUILD_LAUNCHPAD_URL}" "nginx_${BUILD_VER_FILENAME}_source.changes"

elif [[ "${BUILD_MODE}" == 4 ]]
then

    ## User output
    out_l2 \
        "Performing build using SimpleSBuild Enviornment."

    ## Information on pusing to launchpad
    out_sudonotice \
        "SBuild Run:" \
        "cd ${DIR_NGINX}" \
        "sbuild ${OPT_SBUILD}"

    cd "${DIR_NGINX}"
    sbuild ${OPT_SBUILD}

elif [[ "${BUILD_MODE}" == 1 ]]
then

    ## User output
    out_l2 \
        "NOT Installing compiled packages. You can perform this manually via the provided instructions."

    ## Show user steps to remove previous nginx packages without affecting dependencies and then install nginx-scribe
    out_l2 \
        "To replace the standard nginx packages with \"scribe-nginx\", run:" \
        "  sudo dpkg -r --force-all nginx nginx-common nginx-full nginx-light nginx-extra nginx-scribe" \
        "  sudo dpkg -i build/nginx-common_${BUILD_VER_FILENAME}_all.deb build/nginx-scribe_${BUILD_VER_FILENAME}_amd64.deb" \
        "  sudo service nginx restart" \

fi

## User output
out_l1 "All operations completed successfully!"

## EOF
