FROM ubuntu:latest

# Set noninteractive installation and environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/usr/local/bin:$PATH"

WORKDIR /usr/src/app
RUN chmod 777 /usr/src/app

# Install Python 3.12 and essential dependencies
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.12 python3.12-dev python3.12-venv python3-pip \
    libpython3.12 libpython3.12-dev python3.12-distutils

# Install system dependencies
RUN apt-get install -y --no-install-recommends \
    apt-utils aria2 curl zstd git libmagic-dev \
    locales mediainfo neofetch p7zip-full \
    p7zip-rar tzdata wget autoconf automake \
    build-essential cmake g++ gcc gettext \
    gpg-agent intltool libtool make unzip zip \
    libcurl4-openssl-dev libsodium-dev libssl-dev \
    libcrypto++-dev libc-ares-dev libsqlite3-dev \
    libfreeimage-dev swig libboost-all-dev \
    libpthread-stubs0-dev zlib1g-dev \
    # Additional dependencies for enhanced requirements
    libmagic1 libxml2-dev libxslt1-dev \
    libjpeg-dev libpng-dev libffi-dev \
    libgirepository1.0-dev gir1.2-gtk-3.0

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Create directory for binaries
RUN mkdir -p /usr/local/bin

# Install qbittorrent-nox based on architecture
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget -qO /usr/local/bin/xnox https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/x86_64-qbittorrent-nox; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -qO /usr/local/bin/xnox https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/aarch64-qbittorrent-nox; \
    else \
        echo "Unsupported architecture"; exit 1; \
    fi && \
    chmod 700 /usr/local/bin/xnox

# Install and configure FFmpeg
RUN mkdir -p /Temp && cd /Temp && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget https://github.com/5hojib/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-linux64-gpl-7.1.tar.xz; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget https://github.com/5hojib/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-linuxarm64-gpl-7.1.tar.xz; \
    fi && \
    7z x ffmpeg-n7.1-latest-linux*-gpl-7.1.tar.xz && \
    7z x ffmpeg-n7.1-latest-linux*-gpl-7.1.tar && \
    mv /Temp/ffmpeg-n7.1-latest-linux*/bin/ffmpeg /usr/bin/xtra && \
    mv /Temp/ffmpeg-n7.1-latest-linux*/bin/ffprobe /usr/bin/ffprobe && \
    mv /Temp/ffmpeg-n7.1-latest-linux*/bin/ffplay /usr/bin/ffplay && \
    chmod +x /usr/bin/xtra /usr/bin/ffprobe /usr/bin/ffplay

# Install and configure rclone
RUN curl https://rclone.org/install.sh | bash && \
    mv /usr/bin/rclone /usr/bin/xone && \
    mv /usr/bin/aria2c /usr/bin/xria

# Upgrade pip and install essential Python packages
RUN python3.12 -m pip install --upgrade pip && \
    pip3 install --break-system-packages --no-cache-dir -U setuptools wheel six cryptography

# Build and install MEGA SDK
RUN git clone https://github.com/meganz/sdk.git --depth=1 -b v4.8.0 /home/sdk && \
    cd /home/sdk && \
    rm -rf .git && \
    autoupdate -fIv && ./autogen.sh && \
    ./configure --disable-silent-rules --enable-python --with-sodium --disable-examples && \
    make -j$(nproc --all) && \
    cd bindings/python/ && \
    python3.12 setup.py bdist_wheel && \
    pip3 install --break-system-packages --no-cache-dir dist/megasdk-4.8.0-*.whl

# Copy project files
COPY requirements.txt .
COPY . .

# Install project dependencies with retry mechanism for reliability
RUN pip3 install --no-cache-dir -r requirements.txt && \
    if [ $? -ne 0 ]; then \
        sleep 1 && pip3 install --no-cache-dir -r requirements.txt; \
    fi

# Cleanup
RUN apt-get remove -y \
    autoconf automake build-essential cmake g++ gcc gettext \
    gpg-agent intltool libtool make unzip zip libcurl4-openssl-dev \
    libssl-dev libc-ares-dev libsqlite3-dev swig libboost-all-dev \
    libpthread-stubs0-dev zlib1g-dev && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    rm -rf /var/lib/apt/lists/* /Temp /root/.cache

# Set up entrypoint
COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

CMD ["start.sh"]
