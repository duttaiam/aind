#!/bin/bash

# Copyright 2019 root@geeks-r-us.de

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# For further information see: http://geeks-r-us.de/2017/08/26/android-apps-auf-dem-linux-desktop/

# If you find this piece of software useful and or want to support it's development think of
# buying me a coffee https://ko-fi.com/geeks_r_us

# die when an error occurs
set -e

WORKDIR="/anbox-work"

# get latest releasedate based on tag_name for latest x86_64 build
OPENGAPPS_RELEASEDATE="$(curl -s https://api.github.com/repos/opengapps/x86_64/releases/latest | grep tag_name | grep -o "\"[0-9][0-9]*\"" | grep -o "[0-9]*")" 
OPENGAPPS_FILE="open_gapps-x86_64-7.1-pico-$OPENGAPPS_RELEASEDATE.zip"
OPENGAPPS_URL="https://sourceforge.net/projects/opengapps/files/x86_64/$OPENGAPPS_RELEASEDATE/$OPENGAPPS_FILE"

ANBOX=$(which anbox)
OVERLAYDIR="/var/lib/anbox/rootfs-overlay"

echo $WORKDIR
if [ ! -d "$WORKDIR" ]; then
    mkdir "$WORKDIR"
fi

cd "$WORKDIR"

if [ -d "$WORKDIR/squashfs-root" ]; then
  rm -rf squashfs-root
fi
echo "Extracting anbox android image"
unsquashfs /aind-android.img

# get opengapps and install it
echo "Loading open gapps from $OPENGAPPS_URL"
wget -q $OPENGAPPS_URL
echo "extracting open gapps"

unzip -d opengapps ./$OPENGAPPS_FILE

cd ./opengapps/Core/
for filename in *.tar.lz
do
    tar --lzip -xvf ./$filename
done

cd "$WORKDIR"
APPDIR="$OVERLAYDIR/system/priv-app"
mkdir -p "$APPDIR"

cp -r ./$(find opengapps -type d -name "PrebuiltGmsCore")					$APPDIR
cp -r ./$(find opengapps -type d -name "GoogleLoginService")				$APPDIR
cp -r ./$(find opengapps -type d -name "Phonesky")						$APPDIR
cp -r ./$(find opengapps -type d -name "GoogleServicesFramework")			$APPDIR

cd "$APPDIR"
chown -R 100000:100000 Phonesky GoogleLoginService GoogleServicesFramework PrebuiltGmsCore

echo "Modify anbox features"
# add features
C=$(cat <<-END
  <feature name="android.hardware.touchscreen" />\n
  <feature name="android.hardware.audio.output" />\n
  <feature name="android.hardware.camera" />\n
  <feature name="android.hardware.camera.any" />\n
  <feature name="android.hardware.location" />\n
  <feature name="android.hardware.location.gps" />\n
  <feature name="android.hardware.location.network" />\n
  <feature name="android.hardware.microphone" />\n
  <feature name="android.hardware.screen.portrait" />\n
  <feature name="android.hardware.screen.landscape" />\n
  <feature name="android.hardware.wifi" />\n
  <feature name="android.hardware.bluetooth" />"
END
)


C=$(echo $C | sed 's/\//\\\//g')
C=$(echo $C | sed 's/\"/\\\"/g')

if [ ! -d "$OVERLAYDIR/system/etc/permissions/" ]; then
  mkdir -p "$OVERLAYDIR/system/etc/permissions/"
  cp "$WORKDIR/squashfs-root/system/etc/permissions/anbox.xml" "$OVERLAYDIR/system/etc/permissions/anbox.xml"
fi

sed -i "/<\/permissions>/ s/.*/${C}\n&/" "$OVERLAYDIR/system/etc/permissions/anbox.xml"

# make wifi and bt available
sed -i "/<unavailable-feature name=\"android.hardware.wifi\" \/>/d" "$OVERLAYDIR/system/etc/permissions/anbox.xml"
sed -i "/<unavailable-feature name=\"android.hardware.bluetooth\" \/>/d" "$OVERLAYDIR/system/etc/permissions/anbox.xml"

cp "$WORKDIR/squashfs-root/system/build.prop" "$OVERLAYDIR/system/build.prop"
cp "$WORKDIR/squashfs-root/default.prop" "$OVERLAYDIR/default.prop"

# Set specific GLES version
#echo "ro.opengles.version=196608" >> "$OVERLAYDIR/system/build.prop" # GLES 3.0
echo "ro.opengles.version=131072" >> "$OVERLAYDIR/system/build.prop" # GLES 2.0
#echo "ro.opengles.version=65536" >> "$OVERLAYDIR/system/build.prop" # GLES 1.1

#echo "ro.kernel.qemu.gles=0" >> "$OVERLAYDIR/system/build.prop"
#echo "qemu.gles=0" >> "$OVERLAYDIR/system/build.prop"

rm -rf $WORKDIR