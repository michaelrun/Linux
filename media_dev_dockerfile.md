```
FROM ubuntu:20.04

#set proxy
ENV HTTP_PROXY http://host:port
ENV HTTPS_PROXY http://host:port

ADD settz.sh /tmp
# install prerequisites
RUN groupadd dev && \
    useradd -m -d /home/dev -s /bin/bash -g dev dev && \
    chown -R dev:dev /home/dev && \
    echo "dev:admin" | chpasswd && \
    #echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    #usermod -aG sudo dev && \
    echo "Acquire::http::proxy \"http://host:port\";" >> /etc/apt/apt.conf && \
    echo "Acquire::https::proxy \"http://host:port\";" >> /etc/apt/apt.conf && \
    apt update && bash /tmp/settz.sh && apt install -y build-essential git vim tree net-tools nasm yasm mercurial cmake pkg-config && \
    mkdir /home/dev/install /home/dev/src && \
    #
    #build and install x264
    #
    cd /home/dev/src && git clone https://code.videolan.org/videolan/x264.git && \
    cd x264 && ./configure  --prefix=/home/dev/install/ffmpeg --enable-static --enable-shared && \
    make -j && \
    make install && \
    #
    #build and install x265
    #
    echo "[http_proxy]" >> ~/.hgrc && \
    echo "host=host:port" >> ~/.hgrc && \
    echo "no=localmachine,local_ip" >> ~/.hgrc && \
    cd /home/dev/src && hg clone http://hg.videolan.org/x265 && \
    cd x265/build/linux && sed -i 's#cmake#cmake -DCMAKE_INSTALL_PREFIX=/home/dev/install/ffmpeg#g' make-Makefiles.bash && \
    sed -i 's#ccmake#cmake -DCMAKE_INSTALL_PREFIX=/home/dev/install/ffmpeg#g' make-Makefiles.bash && \
    bash make-Makefiles.bash && make -j && make install && \
    #
    #build and install libsvtav1
    #
    cd /home/dev/src && git clone --depth=1 https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    cd SVT-AV1/Build && cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/home/dev/install/ffmpeg && \
    make -j && make install && \
    #
    # build and install ffmpeg
    #
    cd /home/dev/src && git clone https://github.com/FFmpeg/FFmpeg.git && \
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/home/dev/install/ffmpeg/lib" && \
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/home/dev/install/ffmpeg/lib/pkgconfig" && \
    cd FFmpeg && ./configure --prefix=/home/dev/install/ffmpeg --enable-gpl --enable-libx264 --enable-libx265 --enable-libsvtav1 --extra-cflags="-I/home/dev/install/ffmpeg/include" --extra-ldflags="-L/home/dev/install/ffmpeg/lib/"   --extra-ldflags="-L/home/dev/install/ffmpeg/lib64" --cpu=native --enable-pthreads && \
    make -j && make install && \
    chown -R dev:dev /home/dev

#USER dev
WORKDIR /home/dev

ENTRYPOINT ["sleep", "infinity"]

```
