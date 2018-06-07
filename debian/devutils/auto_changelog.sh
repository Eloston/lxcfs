#!/bin/bash

# Updates debian/changelog during a rebase

set -eux

pushd $(git rev-parse --show-toplevel)

trap popd SIGINT

git checkout --theirs -- debian/changelog
TZ=Etc/UTC DEBFULLNAME=Eloston DEBEMAIL=eloston@programmer.net dch --bpo ''
git add debian/changelog

popd
