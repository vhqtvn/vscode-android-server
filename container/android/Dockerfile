FROM bitriseio/android-ndk:v2020_06_06-08_39-b1988
RUN apt -y remove gcc g++ clang
RUN apt -y install curl dirmngr apt-transport-https lsb-release ca-certificates

# Installs node.
RUN curl -sSL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs

# Installs yarn.
RUN curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn

# Installs envsubst.
RUN apt-get install -y gettext-base

# Misc build dependencies.
RUN apt-get install -y git rsync

# We need latest jq from debian buster for date support.
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -sSOL http://http.us.debian.org/debian/pool/main/libo/libonig/libonig5_6.9.1-1_$ARCH.deb && \
    dpkg -i libonig*.deb && \
    curl -sSOL http://http.us.debian.org/debian/pool/main/j/jq/libjq1_1.5+dfsg-2+b1_$ARCH.deb && \
    dpkg -i libjq*.deb && \
    curl -sSOL http://http.us.debian.org/debian/pool/main/j/jq/jq_1.5+dfsg-2+b1_$ARCH.deb && \
    dpkg -i jq*.deb && rm *.deb

RUN apt -y autoremove

RUN apt-get -y update && apt-get install -y make vim nano

RUN add-apt-repository ppa:ubuntu-toolchain-r/test && apt-get update && apt-get install gcc-6 g++-6 gcc-6-multilib g++-6-multilib -y

RUN apt-get -y install libc6-dev-i386

ENV NDK=/opt/android-ndk
ENV NDK_BIN_ROOT=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
ENV ANDROID_ARCH=aarch64
