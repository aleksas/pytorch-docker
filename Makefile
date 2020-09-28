DOCKER_REGISTRY  = docker.io
DOCKER_ORG       = $(shell docker info 2>/dev/null | sed '/Username:/!d;s/.* //')
DOCKER_IMAGE     = pytorch
DOCKER_FULL_NAME = $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_IMAGE)

ifeq ("$(DOCKER_ORG)","")
$(warning WARNING: No docker user found using results from whoami)
DOCKER_ORG       = $(shell whoami)
endif

CPU_IMAGE_RUNTIME	= ubuntu:18.04
CPU_IMAGE_DEVEL		= ubuntu:18.04
CUDA_IMAGE_RUNTIME	= nvidia/cuda:10.1-cudnn7-runtime-ubuntu18.04
CUDA_IMAGE_DEVEL	= nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04

# extra packages installed through apt-get
EXTRA_APT_PACKAGE	=
# extra packages installed through conda
EXTRA_CONDA_PACKAGE	=
# pytorch src directory
SRC_DIR_PYTORCH		=
# vision src directory
SRC_DIR_TORCHVISION	=

PYTHON_VERSION   = 3.7
BUILD_PROGRESS   = auto
BUILD_ARGS       = --build-arg BASE_IMAGE=$(BASE_IMAGE) \
					--build-arg FINAL_IMAGE=$(FINAL_IMAGE) \
					--build-arg APT_CUDA_ENABLE=$(APT_CUDA_ENABLE) \
					--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
					--build-arg EXTRA_APT_PACKAGE=$(EXTRA_APT_PACKAGE) \
					--build-arg EXTRA_CONDA_PACKAGE=$(EXTRA_CONDA_PACKAGE) \
					--build-arg SRC_DIR_PYTORCH=$(SRC_DIR_PYTORCH) \
					--build-arg SRC_DIR_TORCHVISION=$(SRC_DIR_TORCHVISION)
DOCKER_BUILD     = DOCKER_BUILDKIT=1 docker build --progress=$(BUILD_PROGRESS) --target $(BUILD_TYPE) -t $(DOCKER_FULL_NAME):$(DOCKER_TAG) $(BUILD_ARGS) .
DOCKER_PUSH      = docker push $(DOCKER_FULL_NAME):$(DOCKER_TAG)

.PHONY: all
all: cpu-devel-image cpu-runtime-image cuda-devel-image cuda-runtime-image

.PHONY: push
push: cpu-devel-push cpu-runtime-push cuda-devel-push cuda-runtime-push

.PHONY: cpu-devel-image
cpu-devel-image: BASE_IMAGE := $(CPU_IMAGE_DEVEL)
cpu-devel-image: FINAL_IMAGE := $(CPU_IMAGE_DEVEL)
cpu-devel-image: APT_CUDA_ENABLE := 
cpu-devel-image: WITH_CUDA := 
cpu-devel-image: SRC_DIR_PYTORCH := pytorch
cpu-devel-image: SRC_DIR_TORCHVISION := torchvision
cpu-devel-image: BUILD_TYPE := dev
cpu-devel-image: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cpu-devel
cpu-devel-image:
	$(DOCKER_BUILD)

.PHONY: cpu-devel-push
cpu-devel-push: SRC_DIR_PYTORCH := pytorch
cpu-devel-push: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cpu-devel
cpu-devel-push:
	$(DOCKER_PUSH)

.PHONY: cpu-runtime-image
cpu-runtime-image: BASE_IMAGE := $(CPU_IMAGE_DEVEL)
cpu-runtime-image: FINAL_IMAGE := $(CPU_IMAGE_RUNTIME)
cpu-runtime-image: APT_CUDA_ENABLE := 
cpu-runtime-image: WITH_CUDA := 
cpu-runtime-image: SRC_DIR_PYTORCH := pytorch
cpu-runtime-image: SRC_DIR_TORCHVISION := torchvision
cpu-runtime-image: BUILD_TYPE := official
cpu-runtime-image: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cpu-runtime
cpu-runtime-image:
	$(DOCKER_BUILD)

.PHONY: cpu-runtime-push
cpu-runtime-push: SRC_DIR_PYTORCH := pytorch
cpu-runtime-push: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cpu-runtime
cpu-runtime-push:
	$(DOCKER_PUSH)

.PHONY: cuda-devel-image
cuda-devel-image: BASE_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-devel-image: FINAL_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-devel-image: APT_CUDA_ENABLE := 1
cuda-devel-image: WITH_CUDA := 1
cuda-devel-image: SRC_DIR_PYTORCH := pytorch
cuda-devel-image: SRC_DIR_TORCHVISION := torchvision
cuda-devel-image: BUILD_TYPE := dev
cuda-devel-image: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cuda-devel
cuda-devel-image:
	$(DOCKER_BUILD)

.PHONY: cuda-devel-push
cuda-devel-push: SRC_DIR_PYTORCH := pytorch
cuda-devel-push: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cuda-devel
cuda-devel-push:
	$(DOCKER_PUSH)

.PHONY: cuda-runtime-image
cuda-runtime-image: BASE_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-runtime-image: FINAL_IMAGE := $(CUDA_IMAGE_RUNTIME)
cuda-runtime-image: APT_CUDA_ENABLE := 1
cuda-runtime-image: WITH_CUDA := 1
cuda-runtime-image: SRC_DIR_PYTORCH := pytorch
cuda-runtime-image: SRC_DIR_TORCHVISION := torchvision
cuda-runtime-image: BUILD_TYPE := official
cuda-runtime-image: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cuda-runtime
cuda-runtime-image:
	$(DOCKER_BUILD)

.PHONY: cuda-runtime-push
cuda-runtime-push: SRC_DIR_PYTORCH := pytorch
cuda-runtime-push: DOCKER_TAG := $(shell git --git-dir=$(SRC_DIR_PYTORCH)/.git describe --tags)_cuda-runtime
cuda-runtime-push:
	$(DOCKER_PUSH)

.PHONY: clean
clean:
	-docker rmi -f $(shell docker images -q $(DOCKER_FULL_NAME))
