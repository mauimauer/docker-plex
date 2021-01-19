FROM ghcr.io/linuxserver/baseimage-ubuntu:focal

# set version label
ARG BUILD_DATE
ARG VERSION
ARG PLEX_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

#Add needed nvidia environment variables for https://github.com/NVIDIA/nvidia-docker
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

# global environment settings
ENV DEBIAN_FRONTEND="noninteractive" \
PLEX_DOWNLOAD="https://downloads.plex.tv/plex-media-server-new" \
PLEX_ARCH="amd64" \
PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/config/Library/Application Support" \
PLEX_MEDIA_SERVER_HOME="/usr/lib/plexmediaserver" \
PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS="6" \
PLEX_MEDIA_SERVER_USER="abc" \
PLEX_MEDIA_SERVER_INFO_VENDOR="Docker" \
PLEX_MEDIA_SERVER_INFO_DEVICE="Docker Container (LinuxServer.io)"

RUN \
 echo "**** install runtime packages ****" && \
 apt-get update && \
 apt-get install -y software-properties-common && \
 add-apt-repository ppa:oibaf/graphics-drivers -y && \
 apt-get update && \
 apt-get update && \
 apt-get install -y \
	beignet-opencl-icd \
        vainfo \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        libdrm-amdgpu1 \
        libavutil56 \        
	jq \
	ocl-icd-libopencl1 \
	udev \
	unrar \
	wget && \
 COMP_RT_RELEASE=$(curl -sX GET "https://api.github.com/repos/intel/compute-runtime/releases/latest" | jq -r '.tag_name') && \
 COMP_RT_URLS=$(curl -sX GET "https://api.github.com/repos/intel/compute-runtime/releases/tags/${COMP_RT_RELEASE}" | jq -r '.body' | grep wget | sed 's|wget ||g') && \
 mkdir -p /opencl-intel && \
 for i in ${COMP_RT_URLS}; do \
	i=$(echo ${i} | tr -d '\r'); \
	echo "**** downloading ${i} ****"; \
	curl -o "/opencl-intel/$(basename ${i})" \
		-L "${i}"; \
 done && \
 dpkg -i /opencl-intel/*.deb && \
 rm -rf /opencl-intel && \
 echo "**** install plex ****" && \
 if [ -z ${PLEX_RELEASE+x} ]; then \
 	PLEX_RELEASE=$(curl -sX GET 'https://plex.tv/api/downloads/5.json' \
	| jq -r '.computer.Linux.version'); \
 fi && \
 curl -o \
	/tmp/plexmediaserver.deb -L \
	"${PLEX_DOWNLOAD}/${PLEX_RELEASE}/debian/plexmediaserver_${PLEX_RELEASE}_${PLEX_ARCH}.deb" && \
 dpkg -i /tmp/plexmediaserver.deb && \
 echo "**** ensure abc user's home folder is /app ****" && \
 usermod -d /app abc && \
 echo "**** cleanup ****" && \
 apt-get clean && \
 cp /lib/x86_64-linux-gnu/dri/radeonsi_drv_video.so /usr/lib/plexmediaserver/lib/dri/ && \
 cp /lib/x86_64-linux-gnu/libdrm_amdgpu.so.1.* /usr/lib/plexmediaserver/lib/libdrm_amdgpu.so.1 && \
 cp /lib/x86_64-linux-gnu/libdrm.so.2.* /usr/lib/plexmediaserver/lib/libdrm.so.2 && \
 cp /lib/x86_64-linux-gnu/libva-drm.so.2.* /usr/lib/plexmediaserver/lib/libva-drm.so.2 && \
 cp /lib/x86_64-linux-gnu/libva.so.2.* /usr/lib/plexmediaserver/lib/libva.so.2 && \
 cp /lib/x86_64-linux-gnu/libstdc++.so.6.* /usr/lib/plexmediaserver/lib/libstdc++.so.6 && \
 rm -rf \
	/etc/default/plexmediaserver \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# add local files
COPY root/ /

# ports and volumes
EXPOSE 32400/tcp 1900/udp 3005/tcp 5353/udp 8324/tcp 32410/udp 32412/udp 32413/udp 32414/udp 32469/tcp
VOLUME /config
