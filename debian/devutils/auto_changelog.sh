#!/bin/bash

# Updates debian/changelog during a rebase

set -eux

pushd $(dirname $(readlink -f $0))/../../

trap popd SIGINT

git checkout --ours -- debian/changelog
TZ=Etc/UTC DEBFULLNAME=Eloston DEBEMAIL=eloston@programmer.net dch --bpo ''
git add debian/changelog

popd
