#!/bin/bash

# Downloads and unpacks a new upstream debian/ directory from Ubuntu
# It can also bootstrap a debian directory into a new upstream branch after
# the constants have been modified.
# Based on https://gist.github.com/fasheng/7038d3e78479c2e679d2

set -eu

# Constants
_pkgsite='http://archive.ubuntu.com'
pkgsite="${_pkgsite}/ubuntu"
distro=cosmic
pkgname=lxcfs
pkgsection=main
sources_xz_url="$pkgsite/dists/$distro/$pkgsection/source/Sources.xz"

upstream_branch=upstream-ubuntu
our_branch=stretch-backports

# Functions
function grep_block {
    local function_stdin=$(</dev/stdin)
    local keyword="$1"
    awk -v keyword="${keyword}" 'BEGIN{RS="\n\n"} $0 ~ keyword{print ""; print; n++}' /dev/stdin <<< "$function_stdin"
}

# Go to root of repository if necessary
if [ ! -d '.git' ]; then
    cd $(dirname $(readlink -f $0))/../../
    if [ ! -d '.git' ]; then
        echo 'ERROR: Could not find root of git repository'
        exit 1
    fi
fi

# Abort if this isn't a git directory

# We do this early to abort if there are uncommitted changes
git checkout $upstream_branch

# Parse Sources.xz for package's debian.tar.xz
pkg_info=$(curl "$sources_xz_url" | xz -d | grep_block "Package: $pkgname")
pkg_version=$(echo "$pkg_info" | grep -m1 "^Version:" | awk '{print $2}')
pkg_directory=$(echo "$pkg_info" | grep -m1 "^Directory:" | awk '{print $2}')
pkg_file="${pkgname}_${pkg_version}.debian.tar.xz"
pkg_fileurl="${pkgsite}/${pkg_directory}/${pkg_file}"
pkg_sha256sum=$(echo "$pkg_info" | awk 'BEGIN{RS="Checksums-Sha256:"}{if(NR==2){print}}' | grep "${pkg_file}" | awk '{print $1}')

if [ -z "${pkg_version// }" ]; then
    echo 'ERROR: Could not find package in Sources.xz. Aborting'
    exit 1
fi
printf 'INFO: Found version: %s\n' "$pkg_version"
if [ -e debian/changelog ]; then
    if [[ "$(dpkg-parsechangelog --show-field Version)" == "$pkg_version" ]]; then
        printf 'INFO: Already up-to-date. Aborting.\n'
        git checkout $our_branch
        exit 0
    fi
fi

# Download package's debian.tar.xz and compare hashes
pkg_compressed=$(curl "$pkg_fileurl" | base64 -w 0)
pkg_computedsha256sum=$(base64 -d <<< "$pkg_compressed" | sha256sum -b | awk '{print $1}')
if [[ "$pkg_computedsha256sum" != "$pkg_sha256sum" ]]; then
    printf 'ERROR: Hash mismatch: %s != %s\n' "$pkg_computedsha256sum" "$pkg_sha256sum"
    exit 1
fi

# Unpack debian.tar.xz over existing directory
if [ -e debian ]; then
    rm -r debian
fi
base64 -d <<< "$pkg_compressed" | tar xJ

# Make sure there were actually changes to the debian directory
if [ -z "$(git status --porcelain debian)" ]; then
    echo 'ERROR: Debian directory did not change. Aborting.'
    if [ -z "$(git status --porcelain)" ]; then
        git checkout $our_branch
    fi
    exit 1
fi

# So add and commit them
git add debian
git commit --date="$(date --utc +%Y-%m-%dT%H:%M:%S%z)" -m "Import Debian directory $pkg_version"

# Switch back to our branch and begin merge
git checkout $our_branch
git merge $upstream_branch
