#!/bin/bash

# Pulls new code into our upstream branch

set -eu

. $(dirname $(readlink -f $0))/constants.sh

# Go to root of repo to prevent issue of directories disappearing
cd $(git rev-parse --show-toplevel)

git checkout $their_upstream_branch
git remote add upstream https://github.com/lxc/lxcfs.git || true
git pull upstream $their_upstream_branch
git checkout $our_upstream_branch
git merge $their_upstream_branch
git checkout $our_branch
git merge $our_upstream_branch
