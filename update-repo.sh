#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
dpkg-scanpackages -m ./debs > Packages
gzip -c9 Packages > Packages.gz
bzip2 -c9 Packages > Packages.bz2
xz -c9 Packages > Packages.xz
echo "Sileo Repo Packages index updated!"
