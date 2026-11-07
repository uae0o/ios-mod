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

# 4. Rebuild APT Packages indexes & inject per-package Icon:, SileoDepiction:, and Feature Description:
cd "$REPO_DIR"
dpkg-scanpackages -m ./debs > Packages.raw
python3 - "$REPO_DIR" "$ICON_URL" << 'PYEOF'
import sys, os, json, re

repo_dir = sys.argv[1]
default_icon = sys.argv[2]

summaries_path = os.path.join(repo_dir, "depictions", "_summaries.json")
summaries = {}
if os.path.exists(summaries_path):
    with open(summaries_path, "r", encoding="utf-8") as f:
        summaries = json.load(f)

with open(os.path.join(repo_dir, "Packages.raw"), "r", encoding="utf-8", errors="ignore") as f:
    raw = f.read()

blocks = [b.strip() for b in raw.split("\n\n") if b.strip()]
out_blocks = []

for b in blocks:
    lines = b.splitlines()
    pkg = ""
    has_icon = False
    has_depiction = False
    new_lines = []
    for line in lines:
        if line.startswith("Package:"):
            pkg = line.split(":", 1)[1].strip()
            new_lines.append(line)
        elif line.startswith("Description:") and pkg in summaries:
            new_lines.append(f"Description: {summaries[pkg]}")
        elif line.startswith("Icon:"):
            has_icon = True
            new_lines.append(line)
        elif line.startswith("SileoDepiction:"):
            has_depiction = True
            new_lines.append(line)
        else:
            new_lines.append(line)

    if pkg and not has_icon:
        icon_file = os.path.join(repo_dir, "icons", f"{pkg}.png")
        if os.path.exists(icon_file):
            new_lines.append(f"Icon: https://uae0o.github.io/ios-mod/icons/{pkg}.png")
        else:
            new_lines.append(f"Icon: {default_icon}")

    if pkg and not has_depiction:
        dep_file = os.path.join(repo_dir, "depictions", f"{pkg}.json")
        if os.path.exists(dep_file):
            new_lines.append(f"SileoDepiction: https://uae0o.github.io/ios-mod/depictions/{pkg}.json")

    out_blocks.append("\n".join(new_lines))

with open(os.path.join(repo_dir, "Packages"), "w", encoding="utf-8", newline="\n") as f:
    f.write("\n\n".join(out_blocks) + "\n\n")
PYEOF
rm -f Packages.raw

gzip -c9 Packages > Packages.gz
bzip2 -c9 Packages > Packages.bz2
xz -c9 Packages > Packages.xz
echo "Done! Sileo Repo Packages index updated with Icons & SileoDepictions for iphoneos-arm64 and iphoneos-arm64e."
