ARG UBUNTU_VERSION=24.04
ARG NVIDIA_CUDA_VERSION=12.9.1

#
# Docker builder stage.
#
# Kasm base image tag. Images built on 1.20+ bases do not run on Kasm 1.19 and older.
#   1.19.0-rolling-daily -> Kasm 1.19 and older (default)
#   develop              -> Kasm 1.20 (until a 1.20 rolling base tag is published)
ARG BASE_TAG=1.19.0-rolling-daily

FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

ARG COLMAP_GIT_COMMIT=main
ARG CUDA_ARCHITECTURES=all-major
ENV QT_XCB_GL_INTEGRATION=xcb_egl

# Prevent stop building ubuntu at time zone selection.
ENV DEBIAN_FRONTEND=noninteractive

# Prepare and empty machine for building.
RUN apt-get update && \
    apt-get install -y \
        git \
        cmake \
        ninja-build \
        build-essential \
        libboost-program-options-dev \
        libboost-graph-dev \
        libboost-system-dev \
        libeigen3-dev \
        libopenimageio-dev \
        openimageio-tools \
        libmetis-dev \
        libgoogle-glog-dev \
        libgtest-dev \
        libgmock-dev \
        libsqlite3-dev \
        libglew-dev \
        qt6-base-dev \
        libqt6opengl6-dev \
        libqt6openglwidgets6 \
        qt6-svg-dev \
        libcgal-dev \
        libceres-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libmkl-full-dev

# Build and install COLMAP.
RUN git clone https://github.com/colmap/colmap.git
RUN cd colmap && \
    git fetch https://github.com/colmap/colmap.git ${COLMAP_GIT_COMMIT} && \
    git checkout FETCH_HEAD && \
    mkdir build && \
    cd build && \
    cmake .. \
        -GNinja \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
        -DCMAKE_INSTALL_PREFIX=/colmap-install \
        -DBLA_VENDOR=Intel10_64lp && \
    ninja install


FROM kasmweb/core-ubuntu-noble:${BASE_TAG}
USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

######### Customize Container Here ###########

COPY --from=builder /colmap-install/ /usr/local/

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libboost-program-options1.83.0 \
        libc6 \
        libomp5 \
        libopengl0 \
        libmetis5 \
        libceres4t64 \
        libopenimageio2.4t64 \
        libgcc-s1 \
        libgl1 \
        libglew2.2 \
        libgoogle-glog0v6t64 \
        libqt6core6 \
        libqt6gui6 \
        libqt6widgets6 \
        libqt6openglwidgets6 \
        libqt6svg6 \
        libcurl4 \
        libssl3t64 \
        libmkl-locale \
        libmkl-intel-lp64 \
        libmkl-intel-thread \
        libmkl-core && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


COPY ./src/cuda $INST_SCRIPTS/cuda/
RUN bash $INST_SCRIPTS/cuda/install_cuda.sh  && rm -rf $INST_SCRIPTS/cuda/


COPY ./src/colmap/custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh


RUN apt-get update && apt-get install -y gimp nomacs vlc unzip && cp /usr/share/applications/gimp.desktop $HOME/Desktop/ && chmod +x $HOME/Desktop/gimp.desktop

######### End Customizations ###########

RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000