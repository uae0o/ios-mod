#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBS_DIR="$REPO_DIR/debs"
TOOLCHAIN="/home/hunter/theos/toolchain/linux/iphone/bin"
INSTALL_NAME_TOOL="$TOOLCHAIN/install_name_tool"
OTOOL="$TOOLCHAIN/otool"
LDID="$TOOLCHAIN/ldid"
ICON_URL="https://uae0o.github.io/ios-mod/icon.png"

cd "$DEBS_DIR"

# 1. Convert any _iphoneos-arm.deb -> _iphoneos-arm64.deb (if missing)
for deb in *_iphoneos-arm.deb; do
    [ -e "$deb" ] || continue
    base="${deb%_iphoneos-arm.deb}"
    target="${base}_iphoneos-arm64.deb"
    if [ ! -f "$target" ]; then
        echo "Generating Rootless (iphoneos-arm64) package: $target"
        work="/tmp/debconv_$$"
        rm -rf "$work" && mkdir -p "$work/pkg"
        dpkg-deb -R "$deb" "$work/pkg"
        sed -i 's/^Architecture:.*/Architecture: iphoneos-arm64/' "$work/pkg/DEBIAN/control"
        if [ -d "$work/pkg/Library" ]; then
            mkdir -p "$work/pkg/var/jb"
            mv "$work/pkg/Library" "$work/pkg/var/jb/"
        fi
        find "$work/pkg" -name "*.dylib" | while read -r dylib; do
            "$INSTALL_NAME_TOOL" -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate "$dylib" 2>/dev/null || true
            "$INSTALL_NAME_TOOL" -change /usr/lib/libsubstrate.dylib @rpath/libsubstrate.dylib "$dylib" 2>/dev/null || true
            if ! "$OTOOL" -l "$dylib" | grep -q "/var/jb/Library/Frameworks"; then
                "$INSTALL_NAME_TOOL" -add_rpath /var/jb/Library/Frameworks "$dylib" 2>/dev/null || true
                "$INSTALL_NAME_TOOL" -add_rpath /var/jb/usr/lib "$dylib" 2>/dev/null || true
            fi
            if ! "$OTOOL" -l "$dylib" | grep -q "@loader_path/.jbroot/Library/Frameworks"; then
                "$INSTALL_NAME_TOOL" -add_rpath "@loader_path/.jbroot/Library/Frameworks" "$dylib" 2>/dev/null || true
                "$INSTALL_NAME_TOOL" -add_rpath "@loader_path/.jbroot/usr/lib" "$dylib" 2>/dev/null || true
            fi
            "$LDID" -S "$dylib"
        done
        dpkg-deb --root-owner-group -b -Zgzip "$work/pkg" "$target" >/dev/null
        rm -rf "$work"
    fi
done

# 2. Convert any _iphoneos-arm64.deb -> _iphoneos-arm64e.deb (if missing)
for deb in *_iphoneos-arm64.deb; do
    [ -e "$deb" ] || continue
    base="${deb%_iphoneos-arm64.deb}"
    target="${base}_iphoneos-arm64e.deb"
    if [ ! -f "$target" ]; then
        echo "Generating RootHide (iphoneos-arm64e) package: $target"
        work="/tmp/debconv_$$"
        rm -rf "$work" && mkdir -p "$work/pkg"
        dpkg-deb -R "$deb" "$work/pkg"
        sed -i 's/^Architecture:.*/Architecture: iphoneos-arm64e/' "$work/pkg/DEBIAN/control"
        if [ -d "$work/pkg/var/jb" ]; then
            cp -a "$work/pkg/var/jb/." "$work/pkg/"
            rm -rf "$work/pkg/var"
        fi
        find "$work/pkg" -name "*.dylib" | while read -r dylib; do
            "$INSTALL_NAME_TOOL" -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate "$dylib" 2>/dev/null || true
            "$INSTALL_NAME_TOOL" -change /var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate "$dylib" 2>/dev/null || true
            "$INSTALL_NAME_TOOL" -change /usr/lib/libsubstrate.dylib @rpath/libsubstrate.dylib "$dylib" 2>/dev/null || true
            if ! "$OTOOL" -l "$dylib" | grep -q "@loader_path/.jbroot/Library/Frameworks"; then
                "$INSTALL_NAME_TOOL" -add_rpath "@loader_path/.jbroot/Library/Frameworks" "$dylib" 2>/dev/null || true
                "$INSTALL_NAME_TOOL" -add_rpath "@loader_path/.jbroot/usr/lib" "$dylib" 2>/dev/null || true
            fi
            "$LDID" -S "$dylib"
        done
        dpkg-deb --root-owner-group -b -Zgzip "$work/pkg" "$target" >/dev/null
        rm -rf "$work"
    fi
done

# 3. Convert any _iphoneos-arm64e.deb -> _iphoneos-arm64.deb (if missing)
for deb in *_iphoneos-arm64e.deb; do
    [ -e "$deb" ] || continue
    base="${deb%_iphoneos-arm64e.deb}"
    target="${base}_iphoneos-arm64.deb"
    if [ ! -f "$target" ]; then
        echo "Generating Rootless (iphoneos-arm64) package: $target"
        work="/tmp/debconv_$$"
        rm -rf "$work" && mkdir -p "$work/pkg"
        dpkg-deb -R "$deb" "$work/pkg"
        sed -i 's/^Architecture:.*/Architecture: iphoneos-arm64/' "$work/pkg/DEBIAN/control"
        if [ -d "$work/pkg/Library" ]; then
            mkdir -p "$work/pkg/var/jb"
            mv "$work/pkg/Library" "$work/pkg/var/jb/"
        fi
        find "$work/pkg" -name "*.dylib" | while read -r dylib; do
            if ! "$OTOOL" -l "$dylib" | grep -q "/var/jb/Library/Frameworks"; then
                "$INSTALL_NAME_TOOL" -add_rpath /var/jb/Library/Frameworks "$dylib" 2>/dev/null || true
                "$INSTALL_NAME_TOOL" -add_rpath /var/jb/usr/lib "$dylib" 2>/dev/null || true
            fi
            "$LDID" -S "$dylib"
        done
        dpkg-deb --root-owner-group -b -Zgzip "$work/pkg" "$target" >/dev/null
        rm -rf "$work"
    fi
done

# 4. Rebuild APT Packages indexes & inject Icon: for every package in Sileo
cd "$REPO_DIR"
dpkg-scanpackages -m ./debs > Packages.raw
awk -v icon="$ICON_URL" '
/^Package:/ { has_icon = 0 }
/^Icon:/ { has_icon = 1 }
/^$/ {
    if (!has_icon) print "Icon: " icon;
    print "";
    next;
}
{ print }
END {
    if (!has_icon && NR > 0) print "Icon: " icon;
}
' Packages.raw > Packages
rm -f Packages.raw

gzip -c9 Packages > Packages.gz
bzip2 -c9 Packages > Packages.bz2
xz -c9 Packages > Packages.xz
echo "Done! Sileo Repo Packages index updated with Icons for iphoneos-arm, iphoneos-arm64, and iphoneos-arm64e."
