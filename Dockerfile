# syntax = docker/dockerfile:experimental
#
# NOTE: To build this you will need a docker version > 18.06 with
#       experimental enabled and DOCKER_BUILDKIT=1
#
#       If you do not use buildkit you are not going to have a good time
#
#       For reference: 
#           https://docs.docker.com/develop/develop-images/build_enhancements/
ARG BASE_IMAGE=ubuntu:18.04
ARG FINAL_IMAGE=${BASE_IMAGE}

FROM ${BASE_IMAGE} as dev-base
ARG EXTRA_APT_PACKAGE=
ARG APT_CUDA_ENABLE=
RUN --mount=type=cache,id=apt-dev,target=/var/cache/apt \
    if [ -n "${APT_CUDA_ENABLE}" ]; then \
        apt-get -o Dir::Etc::SourceParts='' update && \
        apt-get install -y --no-install-recommends curl && \
        curl -sSL https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
        curl -sSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add -; \
    fi && \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        ccache \
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
RUN /usr/sbin/update-ccache-symlinks
RUN mkdir /opt/ccache && ccache --set-config=cache_dir=/opt/ccache

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
        ${EXTRA_CONDA_PACKAGE} && \
    /opt/conda/bin/conda clean -ya
ENV PATH /opt/conda/bin:$PATH

FROM dev-base as source
ARG SRC_DIR_PYTORCH=pytorch
ARG SRC_DIR_TORCHVISION=torchvision
COPY ${SRC_DIR_PYTORCH} /opt/pytorch
COPY ${SRC_DIR_TORCHVISION} /opt/torchvision
RUN cd /opt/pytorch && git submodule update --init --recursive

FROM conda as build
ARG WITH_CUDA=
COPY --from=source /opt/pytorch /opt/pytorch
COPY --from=source /opt/torchvision /opt/torchvision
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/pytorch && \
    TORCH_CUDA_ARCH_LIST="3.5 5.2 6.0 6.1 7.0+PTX" TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    python setup.py install
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/pytorch && \
    TORCH_CUDA_ARCH_LIST="3.5 5.2 6.0 6.1 7.0+PTX" TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    python tools/build_libtorch.py && \
    cp -r torch/bin torch/include torch/lib torch/share $(dirname $(which conda))/../
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/torchvision && \
    if [ -n "${WITH_CUDA}" ]; then \
        FORCE_CUDA=1 TORCH_CUDA_ARCH_LIST="3.5 5.2 6.0 6.1 7.0+PTX" TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
        CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
        python setup.py install \
    else \
        TORCH_CUDA_ARCH_LIST="3.5 5.2 6.0 6.1 7.0+PTX" TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
        CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
        python setup.py install \
    fi
RUN --mount=type=cache,target=/opt/ccache \
    cd /opt/torchvision && \
    mkdir -p build && \
    cd build && \
    if [ -n "${WITH_CUDA}" ]; then \
        CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"  cmake -DCMAKE_INSTALL_PREFIX="$(dirname $(which conda))/../" .. && \
        make -DWITH_CUDA=on -j $(cat /proc/stat | grep cpu[0-9] -c) && \
        make install \
    else \
        CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"  cmake -DCMAKE_INSTALL_PREFIX="$(dirname $(which conda))/../" .. && \
        make -j $(cat /proc/stat | grep cpu[0-9] -c) && \
        make install \
    fi

FROM build as conda-installs
ARG INSTALL_CHANNEL=pytorch
RUN /opt/conda/bin/conda install -c "${INSTALL_CHANNEL}" -y cudatoolkit=10.1 && \
    /opt/conda/bin/conda clean -ya

FROM ${FINAL_IMAGE} as official
ARG APT_CUDA_ENABLE=
LABEL com.nvidia.volumes.needed="nvidia_driver"
RUN --mount=type=cache,id=apt-final,target=/var/cache/apt \
    if [ -n "${APT_CUDA_ENABLE}" ]; then \
        apt-get -o Dir::Etc::SourceParts='' update && \
        apt-get install -y --no-install-recommends curl && \
        curl -sSL https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
        curl -sSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add -; \
    fi && \
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
COPY --from=conda-installs /opt/conda /opt/conda
ENV PATH /opt/conda/bin:$PATH
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV LD_LIBRARY_PATH /opt/conda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
WORKDIR /workspace

FROM dev-base as dev
LABEL com.nvidia.volumes.needed="nvidia_driver"
COPY --from=conda-installs /opt/conda /opt/conda
COPY --from=build /opt/pytorch /opt/pytorch
COPY --from=build /opt/torchvision /opt/torchvision
ENV PATH /opt/conda/bin:$PATH
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV LD_LIBRARY_PATH /opt/conda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
WORKDIR /workspace
