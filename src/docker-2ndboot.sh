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

adb -a nodaemon server & # launch adb server listening on all interfaces so we can forward the port

Xvfb :0 -screen 0, 1024x768x24 &
export DISPLAY=:0
export EGL_PLATFORM=x11 # workaround, see https://github.com/anbox/anbox/issues/1634

until [ -e /tmp/.X11-unix/X0 ]; do sleep 1; done
blackbox &

x11vnc -nopw -noncache -rfbportv6 -1 -q -forever -bg

if ! systemctl is-system-running --wait; then
    systemctl status --no-pager -l anbox-container-manager
    journalctl -u anbox-container-manager --no-pager -l
    exit 1
fi
systemctl status --no-pager -l anbox-container-manager

anbox session-manager --experimental --single-window --window-size=1024,768 &
until anbox wait-ready; do sleep 1; done
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

adb wait-for-device

# install APKs
for f in /apk-pre.d/*.apk; do adb install -r $f; done

# done
figlet "Ready"
exec sleep infinity
