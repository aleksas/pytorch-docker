# syntax = docker/dockerfile:experimental
#
# NOTE: To build this you will need a docker version > 18.06 with
#       experimental enabled and DOCKER_BUILDKIT=1
#
#       If you do not use buildkit you are not going to have a good time
#
#       For reference: 
#           https://docs.docker.com/develop/develop-images/build_enhancements/
ARG BASE_IMAGE=nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04
ARG FINAL_IMAGE=${BASE_IMAGE}

FROM ${BASE_IMAGE} as dev-base
ARG EXTRA_APT_PACKAGE=
RUN --mount=type=cache,id=apt-dev,target=/var/cache/apt \
    rm -rf /etc/apt/sources.list.d/cuda.list* && \
    rm -rf /etc/apt/sources.list.d/nvidia-ml.list* && \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        libjpeg-dev \
        libpng-dev \
        ${EXTRA_APT_PACKAGE} && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    gnupg \
    software-properties-common \
    wget && \
    curl -sSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null && \
    apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main' && \
    apt-get update && \
    apt-get install -y --no-install-recommends cmake && \
    apt-get upgrade -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

FROM dev-base as conda
ARG PYTHON_VERSION=3.7
ARG EXTRA_CONDA_PACKAGE=
RUN curl -sSL -o ~/miniconda.sh -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda install -y python=${PYTHON_VERSION} \
        conda-build \
        pyyaml \
        numpy \
        ipython \
        typing_extensions \
        pillow \
        future \
        dataclasses \
        numpy \
        opencv \
        ffmpeg \
        ${EXTRA_CONDA_PACKAGE} && \
    /opt/conda/bin/conda clean -ya


RUN /opt/conda/bin/conda install -c pytorch magma-cuda102 && \
    /opt/conda/bin/conda clean -ya

ENV PATH /opt/conda/bin:$PATH

FROM dev-base as source
ARG SRC_DIR_PYTORCH=pytorch
ARG SRC_DIR_TORCHVISION=torchvision
COPY ${SRC_DIR_PYTORCH} /opt/pytorch
COPY ${SRC_DIR_TORCHVISION} /opt/torchvision
RUN cd /opt/pytorch && git submodule update --init --recursive -f

FROM conda as build
ARG TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.5+PTX"
ARG LIBTORCH_INSTALL_DIR="/opt/libtorch"
ARG LIBTORCHVISION_INSTALL_DIR="/opt/libtorch"
COPY --from=source /opt/pytorch /opt/pytorch
COPY --from=source /opt/torchvision /opt/torchvision
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/pytorch && \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    python setup.py install
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/pytorch && \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    python tools/build_libtorch.py && \
    mkdir -p ${LIBTORCH_INSTALL_DIR} && \
    cp -r torch/bin torch/include torch/lib torch/share ${LIBTORCH_INSTALL_DIR}
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/torchvision && \
    FORCE_CUDA=1 TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    python setup.py install
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/torchvision && \
    mkdir -p build && \
    cd build && \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="${LIBTORCH_INSTALL_DIR};$(dirname $(which conda))/../"  cmake -DCMAKE_INSTALL_PREFIX="${LIBTORCHVISION_INSTALL_DIR}" -DWITH_CUDA=on .. && \
    make -j $(cat /proc/stat | grep cpu[0-9] -c) && \
    make install

FROM ${FINAL_IMAGE} as official
ARG LIBTORCH_INSTALL_DIR="/opt/libtorch"
ARG LIBTORCHVISION_INSTALL_DIR="/opt/libtorch"
LABEL com.nvidia.volumes.needed="nvidia_driver"
RUN --mount=type=cache,id=apt-final,target=/var/cache/apt \
    rm -rf /etc/apt/sources.list.d/cuda.list* && \
    rm -rf /etc/apt/sources.list.d/nvidia-ml.list* && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libjpeg-dev \
        libpng-dev && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get upgrade -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/conda /opt/conda
COPY --from=build ${LIBTORCH_INSTALL_DIR} ${LIBTORCH_INSTALL_DIR}
COPY --from=build ${LIBTORCHVISION_INSTALL_DIR} ${LIBTORCHVISION_INSTALL_DIR}
ENV PATH /opt/conda/bin:$PATH
ENV LD_LIBRARY_PATH /opt/conda/lib:/opt/conda/lib64:${LIBTORCH_INSTALL_DIR}/lib:${LIBTORCHVISION_INSTALL_DIR}/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
WORKDIR /workspace

FROM dev-base as dev
ARG LIBTORCH_INSTALL_DIR="/opt/libtorch"
ARG LIBTORCHVISION_INSTALL_DIR="/opt/libtorch"
LABEL com.nvidia.volumes.needed="nvidia_driver"
COPY --from=build /opt/conda /opt/conda
COPY --from=build ${LIBTORCH_INSTALL_DIR} ${LIBTORCH_INSTALL_DIR}
COPY --from=build ${LIBTORCHVISION_INSTALL_DIR} ${LIBTORCHVISION_INSTALL_DIR}
COPY --from=source /opt/pytorch /opt/pytorch
COPY --from=source /opt/torchvision /opt/torchvision
ENV PATH /opt/conda/bin:$PATH
ENV LD_LIBRARY_PATH /opt/conda/lib:/opt/conda/lib64:${LIBTORCH_INSTALL_DIR}/lib:${LIBTORCHVISION_INSTALL_DIR}/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
WORKDIR /workspace
