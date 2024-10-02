FROM ubuntu:24.04


# ------------------------------------------------------
# --- Environments and base directories

# Environments
# - Language
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

# ------------------------------------------------------
# --- Base pre-installed tools
RUN apt-get update -qq

# Generate proper EN US UTF-8 locale
# Install the "locales" package - required for locale-gen
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    locales \
    # Do Locale gen
    && locale-gen en_US.UTF-8

RUN DEBIAN_FRONTEND=noninteractive apt-get -y install \
    git \
    curl \
    wget \
    rsync \
    sudo \
    expect \
    python3 \
    python3-dev \
    python3-pip \
    build-essential \
    zip \
    unzip \
    tree \
    clang \
    jq

# Install NodeJS
#  from official docs: https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
RUN curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -
RUN sudo apt-get install -y nodejs

# Install npm 
# releases: https://github.com/npm/cli/releases
RUN npm install -g npm


# Install Yarn
# as described at: https://yarnpkg.com/en/docs/install#linux-tab
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN DEBIAN_FRONTEND=noninteractive apt-get update -qq && sudo apt-get install -y yarn


# ------------------------------------------------------
# --- SSH config

COPY ./ssh/config /root/.ssh/config

ENV ANDROID_SDK_ROOT /opt/android-sdk-linux
# Preserved for backwards compatibility
ENV ANDROID_HOME /opt/android-sdk-linux

# ------------------------------------------------------
# --- Install required tools

RUN DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common && \
    add-apt-repository ppa:openjdk-r/ppa
RUN dpkg --add-architecture i386

# Base (non android specific) tools
# -> should be added to bitriseio/docker-bitrise-base

# Dependencies to execute Android builds
RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk openjdk-11-jdk libc6:i386 libstdc++6:i386 libgcc1:i386 libncurses6:i386 libz1:i386 net-tools

# Keystore format has changed since JAVA 8 https://bugs.launchpad.net/ubuntu/+source/openjdk-9/+bug/1743139
RUN mv /etc/ssl/certs/java/cacerts /etc/ssl/certs/java/cacerts.old \
    && keytool -importkeystore -destkeystore /etc/ssl/certs/java/cacerts -deststoretype jks -deststorepass changeit -srckeystore /etc/ssl/certs/java/cacerts.old -srcstoretype pkcs12 -srcstorepass changeit \
    && rm /etc/ssl/certs/java/cacerts.old

# Select JAVA 11  as default
RUN sudo update-alternatives --set javac /usr/lib/jvm/java-11-openjdk-amd64/bin/javac
RUN sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java

# ------------------------------------------------------
# --- Download Android Command line Tools into $ANDROID_SDK_ROOT

RUN cd /opt \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip -O android-commandline-tools.zip \
    && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && unzip -q android-commandline-tools.zip -d /tmp/ \
    && mv /tmp/cmdline-tools/ ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm android-commandline-tools.zip && ls -la ${ANDROID_SDK_ROOT}/cmdline-tools/latest/

ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin

# ------------------------------------------------------
# --- Install Android SDKs and other build packages

# Other tools and resources of Android SDK
#  you should only install the packages you need!
# To get a full list of available options you can use:
#  sdkmanager --list

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses

RUN touch /root/.android/repositories.cfg

# Emulator and Platform tools
RUN yes | sdkmanager "emulator" "platform-tools"

# SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.

RUN yes | sdkmanager --update --channel=0
# Please keep all sections in descending order!
RUN yes | sdkmanager \
    "platforms;android-30" \
    "platforms;android-29" \
    "platforms;android-28" \
    "platforms;android-27" \
    "platforms;android-26" \
    "platforms;android-25" \
    "platforms;android-24" \
    "platforms;android-23" \
    "platforms;android-22" \
    "platforms;android-21" \
    "platforms;android-19" \
    "platforms;android-17" \
    "platforms;android-15" \
    "build-tools;30.0.3" \
    "build-tools;30.0.2" \
    "build-tools;30.0.0" \
    "build-tools;29.0.3" \
    "build-tools;29.0.2" \
    "build-tools;29.0.1" \
    "build-tools;29.0.0" \
    "build-tools;28.0.3" \
    "build-tools;28.0.2" \
    "build-tools;28.0.1" \
    "build-tools;28.0.0" \
    "build-tools;27.0.3" \
    "build-tools;27.0.2" \
    "build-tools;27.0.1" \
    "build-tools;27.0.0" \
    "build-tools;26.0.2" \
    "build-tools;26.0.1" \
    "build-tools;25.0.3" \
    "build-tools;24.0.3" \
    "build-tools;23.0.3" \
    "build-tools;22.0.1" \
    "build-tools;21.1.2" \
    "build-tools;19.1.0" \
    "build-tools;17.0.0" \
    "system-images;android-30;google_apis;x86" \
    "system-images;android-29;google_apis;x86" \
    "system-images;android-28;google_apis;x86_64" \
    "system-images;android-26;google_apis;x86" \
    "system-images;android-25;google_apis;armeabi-v7a" \
    "system-images;android-24;default;armeabi-v7a" \
    "system-images;android-22;default;armeabi-v7a" \
    "system-images;android-19;default;armeabi-v7a" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "extras;google;google_play_services" \
    "add-ons;addon-google_apis-google-23" \
    "add-ons;addon-google_apis-google-22" 

# ------------------------------------------------------
# --- Install Gradle from PPA

# Gradle PPA
ENV GRADLE_VERSION=8.10
ENV PATH=$PATH:"/opt/gradle/gradle-8.10/bin/"
RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp \
    && unzip -d /opt/gradle /tmp/gradle-*.zip \
    && chmod +775 /opt/gradle \
    && gradle --version \
    && rm -rf /tmp/gradle*

# ------------------------------------------------------
# --- Install Maven 3 from PPA

RUN apt-get purge maven maven2 \
 && apt-get update \
 && apt-get -y install maven \
 && mvn --version

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64


# ------------------------------------------------------
# --- Cleanup and rev num

# Cleaning
RUN apt-get clean

ENV ANDROID_NDK_HOME /opt/android-ndk
ENV ANDROID_NDK_VERSION r27b
ENV GCE_METADATA_ROOT 127.0.0.1


# ------------------------------------------------------
# --- Install required tools

RUN apt-get update -qq && \
    apt-get clean


# ------------------------------------------------------
# --- Android NDK

# download
RUN mkdir /opt/android-ndk-tmp && \
    cd /opt/android-ndk-tmp && \
    wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
# uncompress
    unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
# move to its final location
    mv ./android-ndk-${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME} && \
# remove temp dir
    cd ${ANDROID_NDK_HOME} && \
    rm -rf /opt/android-ndk-tmp

# add to PATH
ENV PATH ${PATH}:${ANDROID_NDK_HOME}


ARG PYTHON_VERSION=3.11.9

ENV PYTHON_VERSION=${PYTHON_VERSION}

RUN DEBIAN_FRONTEND=noninteractive apt -y remove gcc gcc-10 g++ clang
RUN DEBIAN_FRONTEND=noninteractive apt-get -y update \
 && DEBIAN_FRONTEND=noninteractive apt -y install \
    curl dirmngr apt-transport-https lsb-release ca-certificates

# Installs yarn.
RUN curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y yarn

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y gettext-base \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y jq make vim nano

RUN DEBIAN_FRONTEND=noninteractive apt -y autoremove

RUN update-alternatives --remove-all gcc || true; update-alternatives --remove-all g++ || true

RUN add-apt-repository ppa:ubuntu-toolchain-r/test && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install gcc-10 g++-10 gcc-10-multilib g++-10-multilib -y

RUN mkdir -p /tmp/python-build && cd /tmp/python-build && \
    DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y libbz2-dev && \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xf Python-*.tgz && cd Python-* && \
    ./configure --enable-optimizations && \
    make -j 4 && sudo make install

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 10 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30 && \
    update-alternatives --set cc /usr/bin/gcc && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30 && \
    update-alternatives --set c++ /usr/bin/g++ && \
    update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python$(echo ${PYTHON_VERSION} | awk 'BEGIN{FS=OFS="."} NF--') 1

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install libc6-dev-i386
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN . ~/.cargo/env && rustup target add x86_64-linux-android i686-linux-android aarch64-linux-android armv7-linux-androideabi

ENV NDK=/opt/android-ndk
ENV NDK_BIN_ROOT=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
ENV ANDROID_ARCH=aarch64

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install quilt

# install git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install git-lfs

RUN git config --global --add safe.directory /vscode \
    && git config --global --add safe.directory /vscode/code-server \
    && git config --global --add safe.directory /vscode/code-server/lib/vscode \
    && git config --global --add safe.directory /vscode/node-src

ENTRYPOINT /bin/bash
