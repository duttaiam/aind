# this dockerfile can be translated to `docker/dockerfile:1-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile | DOCKER_BUILDKIT=1 docker build -f -  .

ARG BASE=ubuntu:rolling

# Nov 19, 2020
ARG ANBOX_COMMIT=3fa48f9876e1ac5de9b8ae8948c0e5f7300ee436

# From: https://git.droidware.info/wchen342/ungoogled-chromium-android/releases
# v86.0.4240.111-1 ChromeModernPublic_x86.apk
ARG UNGOOGLED_HASH=db5a8c23-8c3b-4392-a367-5408262b2831

# ARG ANDROID_IMAGE=https://build.anbox.io/android-images/2018/07/19/android_amd64.img
# Mirror
#ARG ANDROID_IMAGE=https://github.com/AkihiroSuda/anbox-android-images-mirror/releases/download/snapshot-20180719/android_amd64.img
#ARG ANDROID_IMAGE_SHA256=6b04cd33d157814deaf92dccf8a23da4dc00b05ca6ce982a03830381896a8cca

# New build by https://fjordtek.com/git/Fincer/anbox-install
#ARG ANDROID_IMAGE=https://fjordtek.com/pool/applications/anbox/images/android_7.1.1_r13_patched.img
#ARG ANDROID_IMAGE_SHA256=44bc2e621251d18ab9a44b97c9006794fbad39a377fae60a09f2d320940fcbb2

# New build by http://anbox.postmarketos.org/
ARG ANDROID_IMAGE=http://anbox.postmarketos.org/android-7.1.2_r39-anbox_x86_64-userdebug.img
ARG ANDROID_IMAGE_SHA256=f5fe1d520bbf132eae7c48d7d6250d20b5f3f753969076254f210baaca8f759b

FROM ${BASE} AS anbox
ENV DEBIAN_FRONTEND=noninteractive
RUN \
  #echo "deb [trusted=yes] http://ppa.launchpad.net/kisak/kisak-mesa/ubuntu focal main" >> /etc/apt/sources.list && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -qq -y --no-install-recommends \
  build-essential \
  ca-certificates \
  cmake \
  cmake-data \
  cmake-extras \
  debhelper \
  dbus \
  git \
  google-mock \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-log-dev \
  libboost-iostreams-dev \
  libboost-program-options-dev \
  libboost-system-dev \
  libboost-test-dev \
  libboost-thread-dev \
  libcap-dev \
  libegl1-mesa-dev \
  libexpat1-dev \
  libgles2-mesa-dev \
  libglm-dev \
  libgtest-dev \
  liblxc1 \
  libproperties-cpp-dev \
  libprotobuf-dev \
  libsdl2-dev \
  libsdl2-image-dev \
  libsystemd-dev \
  lxc-dev \
  pkg-config \
  protobuf-compiler \
  python3-minimal
RUN git clone --recursive https://github.com/anbox/anbox /anbox
WORKDIR /anbox
ARG ANBOX_COMMIT
RUN git pull && git checkout ${ANBOX_COMMIT} && git submodule update --recursive
COPY ./src/patches/anbox /patches
# `git am` requires user info to be set
#RUN git config user.email "nobody@example.com" && git config user.name "AinD Build Script" && git am /patches/*.patch && git show --summary
# runopt = --mount=type=cache,id=aind-anbox,target=/build
RUN ./scripts/build.sh && \
  cp -f ./build/src/anbox /anbox-binary && \
  rm -rf ./build

FROM ${BASE} AS android-img
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  ca-certificates curl
ARG ANDROID_IMAGE
ARG ANDROID_IMAGE_SHA256
RUN curl --retry 10 -L -o /android.img $ANDROID_IMAGE \
    && echo $ANDROID_IMAGE_SHA256 /android.img | sha256sum --check

FROM ${BASE}
ENV DEBIAN_FRONTEND=noninteractive
ARG UNGOOGLED_HASH
RUN \
  #echo "deb [trusted=yes] http://ppa.launchpad.net/kisak/kisak-mesa/ubuntu focal main" >> /etc/apt/sources.list && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -qq -y --no-install-recommends \
# base system
  ca-certificates curl iproute2 jq kmod socat \
# lxc
  iptables lxc \
# anbox deps
  libboost-log1.71.0  libboost-thread1.71.0 libboost-program-options1.71.0 libboost-iostreams1.71.0 libboost-filesystem1.71.0 libprotobuf-lite23 libsdl2-2.0-0 libsdl2-image-2.0-0 \
# squashfuse
  squashfuse fuse3 \
# adb
  adb \
# systemd
  dbus dbus-user-session systemd systemd-container systemd-sysv \
# X11
  xvfb x11vnc \
# WM
  blackbox xterm \
# debug utilities
  busybox figlet file strace less \
# MESA libs
  libegl1-mesa libgles2-mesa \
# Squash tools
  lzip squashfs-tools unzip wget && \
# Homedir, entrypoint
  useradd --create-home --home-dir /home/user -s /bin/bash --uid 1000 -G systemd-journal,audio,video user  && \
  curl -L -o /docker-entrypoint.sh https://raw.githubusercontent.com/AkihiroSuda/containerized-systemd/master/docker-entrypoint.sh && \
  chmod +x /docker-entrypoint.sh && \
# apk-pre.d is for pre-installed apks
  mkdir -p /apk-pre.d && \
# Firefox from: https://github.com/mozilla-mobile/fenix/releases/ (x86_64 apk)
  curl -L -o /apk-pre.d/firefox.apk https://github.com/mozilla-mobile/fenix/releases/download/v82.1.2/fenix-82.1.2-x86_64.apk && \
# Chrome from: https://git.droidware.info/wchen342/ungoogled-chromium-android/releases (ChromeModernPublic_x86.apk)
  curl -L -o /apk-pre.d/chromium.apk https://git.droidware.info/attachments/${UNGOOGLED_HASH} && \
# Chrome from https://github.com/ungoogled-software/ungoogled-chromium-android 
#  curl -L -o /apk-pre.d/chromium.apk "http://server.niekvandermaas.nl/chrome.apk" && \
  chmod 444 /apk-pre.d/* && \
  rm -rf /var/lib/apt/lists/*
VOLUME /var/lib/anbox
COPY --from=android-img /android.img /aind-android.img
COPY --from=anbox /anbox-binary /usr/local/bin/anbox
COPY --from=anbox /anbox/scripts/anbox-bridge.sh /usr/local/share/anbox/anbox-bridge.sh
COPY --from=anbox /anbox/data/ui /usr/local/share/anbox/ui
COPY --from=anbox /anbox/android/media/* /var/lib/anbox/rootfs-overlay/system/etc/
ADD src/anbox-container-manager-pre.sh /usr/local/bin/anbox-container-manager-pre.sh
ADD src/anbox-container-manager.service /lib/systemd/system/anbox-container-manager.service
ADD src/install-playstore.sh /root/install-playstore.sh
# unsquashfs -d /tmp/rootfs-overlay/ /aind-android.img default.prop system/build.prop && cp -R /tmp/rootfs-overlay/* /var/lib/anbox/rootfs-overlay/ && rm -rf /tmp/rootfs-overlay
RUN /root/install-playstore.sh && ldconfig && systemctl enable anbox-container-manager
ADD src/unsudo /usr/local/bin
ADD src/docker-2ndboot.sh  /home/user
# Either copy SwiftShader libs below, or install: libegl1-mesa libgles2-mesa
#ADD swiftshader/libEGL.so /usr/lib/x86_64-linux-gnu/libEGL.so.1
#ADD swiftshader/libGLESv2.so /usr/lib/x86_64-linux-gnu/libGLESv2.so.2
# Usage: docker run --rm --privileged -v /:/host --entrypoint bash aind/aind -exc "cp -f /install-kmod.sh /host/aind-install-kmod.sh && cd /host && chroot . /aind-install-kmod.sh"
ADD hack/install-kmod.sh /
ENTRYPOINT ["/docker-entrypoint.sh", "unsudo"]
EXPOSE 5900
EXPOSE 5037
HEALTHCHECK --interval=15s --timeout=10s --start-period=60s --retries=5 \
  CMD ["pgrep", "-f", "org.anbox.appmgr"]
CMD ["/home/user/docker-2ndboot.sh"]