FROM debian:bookworm

RUN \
	apt-get update \
	&& apt-get install -y \
		bison \
		bzip2 \
		flex \
		g++ \
		gcc \
		make \
		patch \
		wget \
		xz-utils \
		yasm \
	&& apt-get install -y \
		autoconf \
		cmake \
		libtool \
		libz-dev \
		python-is-python3 \
		python3-distutils \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

COPY \
	functions.sh /burp-cross-tools/

COPY \
	cross-tools /burp-cross-tools/cross-tools
RUN  \
	cd /burp-cross-tools \
	&& ./cross-tools/build-script.sh \
	&& rm -rf cross-tools/source

COPY \
	depkgs /burp-cross-tools/depkgs
RUN \
	cd /burp-cross-tools \
	&& ./depkgs/build-script.sh \
	&& rm -rf depkgs/source

RUN \
	apt-get update \
	&& apt-get install -y pkg-config check librsync-dev \
		libssl-dev uthash-dev libyajl-dev libacl1-dev libncurses-dev \
		lcov openssh-client \
	&& rm -rf /var/lib/apt/lists/*
RUN \
	apt-get update \
	&& apt-get install -y valgrind \
	&& rm -rf /var/lib/apt/lists/*

EXPOSE 4971
