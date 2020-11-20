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

WORKDIR="$(pwd)/anbox-work"

# get latest releasedate based on tag_name for latest x86_64 build
OPENGAPPS_RELEASEDATE="$(curl -s https://api.github.com/repos/opengapps/x86_64/releases/latest | head -n 10 | grep tag_name | grep -o "\"[0-9][0-9]*\"" | grep -o "[0-9]*")" 
OPENGAPPS_FILE="open_gapps-x86_64-7.1-pico-$OPENGAPPS_RELEASEDATE.zip"
OPENGAPPS_URL="https://sourceforge.net/projects/opengapps/files/x86_64/$OPENGAPPS_RELEASEDATE/$OPENGAPPS_FILE"

HOUDINI_Y_URL="http://dl.android-x86.org/houdini/7_y/houdini.sfs"
HOUDINI_Z_URL="http://dl.android-x86.org/houdini/7_z/houdini.sfs"

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
wget -q --show-progress $OPENGAPPS_URL
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

echo "adding lib houdini"

# load houdini_y and spread it
cd "$WORKDIR"
if [ ! -f ./houdini_y.sfs ]; then
  wget -O houdini_y.sfs -q --show-progress $HOUDINI_Y_URL
  mkdir -p houdini_y
  unsquashfs -f -d ./houdini_y ./houdini_y.sfs
fi

LIBDIR="$OVERLAYDIR/system/lib"
mkdir -p "$LIBDIR/arm"

cp -r ./houdini_y/* "$LIBDIR/arm"
chown -R 100000:100000 "$LIBDIR/arm"
mv "$LIBDIR/arm/libhoudini.so" "$LIBDIR/libhoudini.so"

# load houdini_z and spread it

if [ ! -f ./houdini_z.sfs ]; then
  wget -O houdini_z.sfs -q --show-progress $HOUDINI_Z_URL
  mkdir -p houdini_z
  unsquashfs -f -d ./houdini_z ./houdini_z.sfs
fi

LIBDIR64="$OVERLAYDIR/system/lib64"
mkdir -p "$LIBDIR64"

mkdir -p "$LIBDIR64/arm64"
cp -r ./houdini_z/* "$LIBDIR64/arm64"
chown -R 100000:100000 "$LIBDIR64/arm64"
mv "$LIBDIR64/arm64/libhoudini.so" "$LIBDIR64/libhoudini.so"

# add houdini parser
BINFMT_DIR="/proc/sys/fs/binfmt_misc/register"
set +e
echo ':arm_exe:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28::/system/lib/arm/houdini:P' | tee -a "$BINFMT_DIR"
echo ':arm_dyn:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\x28::/system/lib/arm/houdini:P' | tee -a "$BINFMT_DIR"
echo ':arm64_exe:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7::/system/lib64/arm64/houdini64:P' | tee -a "$BINFMT_DIR"
echo ':arm64_dyn:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7::/system/lib64/arm64/houdini64:P' | tee -a "$BINFMT_DIR"

set -e

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

if [ ! -x "$OVERLAYDIR/system/build.prop" ]; then
  cp "$WORKDIR/squashfs-root/system/build.prop" "$OVERLAYDIR/system/build.prop"
fi

if [ ! -x "$OVERLAYDIR/default.prop" ]; then
  cp "$WORKDIR/squashfs-root/default.prop" "$OVERLAYDIR/default.prop"
fi

# set processors
sed -i "/^ro.product.cpu.abilist=x86_64,x86/ s/$/,armeabi-v7a,armeabi,arm64-v8a/" "$OVERLAYDIR/system/build.prop"
sed -i "/^ro.product.cpu.abilist32=x86/ s/$/,armeabi-v7a,armeabi/" "$OVERLAYDIR/system/build.prop"
sed -i "/^ro.product.cpu.abilist64=x86_64/ s/$/,arm64-v8a/" "$OVERLAYDIR/system/build.prop"

echo "persist.sys.nativebridge=1" | tee -a "$OVERLAYDIR/system/build.prop"
sed -i '/ro.zygote=zygote64_32/a\ro.dalvik.vm.native.bridge=libhoudini.so' "$OVERLAYDIR/default.prop"

# enable opengles, 131072 = 2 in HEX
echo "ro.opengles.version=131072" | tee -a "$OVERLAYDIR/system/build.prop"