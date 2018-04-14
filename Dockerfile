FROM debian:stretch

RUN \
	apt-get update \
	&& apt-get install -y gcc g++ make flex bison \
		patch yasm wget bzip2 xz-utils \
	&& apt-get install -y cmake autoconf libtool unzip libz-dev python \
	&& rm -rf /var/lib/apt/lists/*

COPY \
	. /burp-cross-tools

RUN  \
	cd /burp-cross-tools \
	&& ./cross-tools/build-script.sh \
	&& rm -rf cross-tools/source \
	&& ./depkgs/build-script.sh \
	&& rm -rf depkgs/source

RUN \
	apt-get update \
	&& apt-get install -y pkg-config check librsync-dev \
		libssl-dev uthash-dev libyajl-dev libacl1-dev libncurses-dev \
		lcov \
	&& rm -rf /var/lib/apt/lists/*

EXPOSE 4971
