#!/usr/bin/env bash
# Installs the Android emulator and one AVD into the repo (no admin rights, ~2.2 GB download).
#   scripts/install-emulator.sh            # AVD "photobooking_api35"
# Like install-sdk.sh, it downloads the zips from dl.google.com with curl, because sdkmanager
# cannot fetch its package lists through the proxy. The AVD lives in .home/.android/avd;
# scripts/bin/flutter and .vscode/settings.json point there, so
# `scripts/bin/flutter emulators --launch photobooking_api35` and the VS Code device picker see it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/bin/_jvm-env.sh"
SDK="$ANDROID_HOME"
REPO="https://dl.google.com/android/repository"
API=35
TAG=google_apis_playstore
case "$(uname -m)" in arm64) ABI=arm64-v8a; HOST_ARCH=aarch64; CPU=arm64 ;; *) ABI=x86_64; HOST_ARCH=x64; CPU=x86_64 ;; esac
NAME="photobooking_api$API"
IMG_DIR="$SDK/system-images/android-$API/$TAG/$ABI"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/emu.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Prints the zip file name of the newest stable (channel-0) archive of package $2 in manifest $1.
latest_zip() {
  python3 - "$1" "$2" "$HOST_ARCH" <<'EOF'
import sys, xml.etree.ElementTree as ET
manifest, path, arch = sys.argv[1:]
best = None
for p in ET.parse(manifest).getroot().iter('remotePackage'):
    if p.get('path') != path or p.find('channelRef').get('ref') != 'channel-0':
        continue
    rev = tuple(int(x.text) for x in p.find('revision') if x.text)
    for a in p.iter('archive'):
        os_, a_arch = a.findtext('host-os'), a.findtext('host-arch')
        if os_ not in (None, 'macosx') or a_arch not in (None, arch):
            continue
        if best is None or rev > best[0]:
            best = (rev, a.findtext('complete/url'))
if best is None:
    sys.exit(f'no stable archive for {path}')
print(best[1])
EOF
}

if [ ! -x "$SDK/emulator/emulator" ]; then
  curl -fsSL -o "$TMP/repo.xml" "$REPO/repository2-3.xml"
  ZIP="$(latest_zip "$TMP/repo.xml" emulator)"
  echo "== emulator: $ZIP"
  curl -fL --progress-bar -o "$TMP/emu.zip" "$REPO/$ZIP"
  unzip -q "$TMP/emu.zip" -d "$SDK"   # the zip holds an emulator/ folder
fi

if [ ! -f "$IMG_DIR/system.img" ]; then
  curl -fsSL -o "$TMP/sys.xml" "$REPO/sys-img/$TAG/sys-img2-3.xml"
  ZIP="$(latest_zip "$TMP/sys.xml" "system-images;android-$API;$TAG;$ABI")"
  echo "== system image: $ZIP"
  curl -fL --progress-bar -o "$TMP/img.zip" "$REPO/sys-img/$TAG/$ZIP"
  unzip -q "$TMP/img.zip" -d "$TMP/img"   # the zip holds an <abi>/ folder
  mkdir -p "$(dirname "$IMG_DIR")" && rm -rf "$IMG_DIR" && mv "$TMP/img/$ABI" "$IMG_DIR"
fi

AVD="$ANDROID_AVD_HOME/$NAME.avd"
if [ -f "$AVD/config.ini" ]; then
  echo "AVD $NAME already exists"
else
  mkdir -p "$AVD"
  printf 'avd.ini.encoding=UTF-8\npath=%s\npath.rel=avd/%s.avd\ntarget=android-%s\n' \
    "$AVD" "$NAME" "$API" > "$ANDROID_AVD_HOME/$NAME.ini"
  cat > "$AVD/config.ini" <<EOF
AvdId=$NAME
avd.ini.displayname=Photobooking API $API
avd.ini.encoding=UTF-8
abi.type=$ABI
hw.cpu.arch=$CPU
image.sysdir.1=system-images/android-$API/$TAG/$ABI/
tag.id=$TAG
tag.display=Google Play
PlayStore.enabled=true
hw.lcd.width=1080
hw.lcd.height=2400
hw.lcd.density=420
hw.ramSize=4096
vm.heapSize=512
disk.dataPartition.size=6G
hw.keyboard=yes
hw.gpu.enabled=yes
hw.gpu.mode=auto
EOF
fi
"$SDK/emulator/emulator" -list-avds | grep -qx "$NAME" || { echo "emulator does not list $NAME"; exit 1; }
echo "Done. Start it with: scripts/bin/flutter emulators --launch $NAME (or pick it in VS Code)."
