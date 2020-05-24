FROM bitriseio/android-ndk:v2020_03_28-08_15-b1903
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

ENV NDK=/opt/android-ndk

