#!/bin/bash
# docker-2ndboot.sh is executed as a non-root user via `unsudo`.

function finish {
    set +x
    figlet ERROR
    : FIXME: the container should shutdown automatically here
}
trap finish EXIT

cd $(realpath $(dirname $0)/..)
set -eux

Xvfb :0 -screen 0, 1024x768x24 &
export DISPLAY=:0
blackbox &

until [ -e /tmp/.X11-unix/X0 ]; do sleep 1; done

if [ -z "$NO_VNC_PASS" ]; then
    mkdir -p ~/.vnc
    if [ ! -e ~/.vnc/passwdfile ]; then
        set +x
        echo $(head /dev/urandom | tr -dc a-z0-9 | head -c 32) > ~/.vnc/passwdfile
        set -x
    fi
    x11vnc -display 0 -usepw -noncache -rfbportv6 -1 -q -forever -bg
else
    x11vnc -display 0 -nopw -noncache -rfbportv6 -1 -q -forever -bg
fi

if ! systemctl is-system-running --wait; then
    systemctl status --no-pager -l anbox-container-manager
    journalctl -u anbox-container-manager --no-pager -l
    exit 1
fi
systemctl status --no-pager -l anbox-container-manager

export SWIFTSHADER_PATH=/usr/local/lib
anbox session-manager --software-renderer --experimental --window-size=1024,768 &
until anbox wait-ready; do sleep 1; done
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

adb wait-for-device

# install APKs
for f in {/apk-pre.d/,/apk.d/}*.apk; do adb install -r $f; done

# done
figlet "Ready"
if [ -z "$NO_VNC_PASS" ]; then
    echo "Hint: the password is stored in $HOME/.vnc/passwdfile"
fi
exec sleep infinity
