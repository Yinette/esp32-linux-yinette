FROM ubuntu:22.04 AS jammy-base

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt -y update \
    && apt -y upgrade

RUN apt -y install gcc g++ gperf bison flex texinfo help2man make libncurses5-dev \
    python3-dev automake libtool libtool-bin gawk wget bzip2 xz-utils unzip \
    patch libstdc++6 rsync git meson ninja-build

FROM jammy-base AS esp32-linux-buildchain

RUN groupadd -g 1001 builder && \
    useradd -m -u 1001 -g builder builder

# Autoconf/Autoreconf
RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz \
    && tar -xf autoconf-2.71.tar.xz \
    && cd autoconf-2.71 \
    && ./configure \
    && make -j`nproc` && make install

RUN mkdir /usr/local/src/esp32-linux && chown builder: /usr/local/src/esp32-linux
USER builder

WORKDIR /usr/local/src/esp32-linux

# Dynconfig
RUN git clone https://github.com/jcmvbkbc/xtensa-dynconfig -b original \
    && git clone https://github.com/jcmvbkbc/config-esp32s3 esp32s3 \
    && make -j`nproc` -C xtensa-dynconfig ORIG=1 CONF_DIR=`pwd` esp32s3.so

ENV XTENSA_GNU_CONFIG=/usr/local/src/esp32-linux/xtensa-dynconfig/esp32s3.so

# Toolchain
RUN git clone https://github.com/jcmvbkbc/crosstool-NG.git -b xtensa-fdpic
WORKDIR /usr/local/src/esp32-linux/crosstool-NG
RUN ./bootstrap 
RUN ./configure --enable-local && make -j`nproc`
RUN ./ct-ng xtensa-esp32s3-linux-uclibcfdpic
RUN CT_PREFIX=`pwd`/builds ./ct-ng build

FROM esp32-linux-buildchain AS esp32-linux-builder

WORKDIR /usr/local/src/esp32-linux

COPY /bin/build-esp32-linux.sh /usr/local/src/esp32-linux

#ENTRYPOINT 