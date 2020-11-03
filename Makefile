DOCKER_REGISTRY  = docker.io
DOCKER_ORG       = $(shell docker info 2>/dev/null | sed '/Username:/!d;s/.* //')
DOCKER_IMAGE     = pytorch
DOCKER_FULL_NAME = $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_IMAGE)

ifeq ("$(DOCKER_ORG)","")
$(warning WARNING: No docker user found using results from whoami)
DOCKER_ORG       = $(shell whoami)
endif

CUDA_IMAGE_RUNTIME	= nvidia/cuda:10.2-cudnn7-runtime-ubuntu18.04
CUDA_IMAGE_DEVEL	= nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04

# extra packages installed through apt-get
EXTRA_APT_PACKAGE	=
# extra packages installed through conda
EXTRA_CONDA_PACKAGE	=
# pytorch src directory
SRC_DIR_PYTORCH		= pytorch
# vision src directory
SRC_DIR_TORCHVISION	= torchvision
# libtorch install directory
LIBTORCH_INSTALL_DIR		= /opt/libtorch
# libtorchvision install directory
LIBTORCHVISION_INSTALL_DIR	= /opt/libtorch
# cuda arch list
TORCH_CUDA_ARCH_LIST		= "3.5 5.2 6.0 6.1 7.0 7.5+PTX"
TORCH_CUDA_ARCH_LIST_10_1	= "3.5 5.2 6.0 6.1 7.0 7.5+PTX"
TORCH_CUDA_ARCH_LIST_10_2	= "3.5 5.2 6.0 6.1 7.0 7.5+PTX"
TORCH_CUDA_ARCH_LIST_11_0	= "3.5 5.2 6.0 6.1 7.0 7.5 8.0+PTX"
TORCH_CUDA_ARCH_LIST_11_1	= "3.5 5.2 6.0 6.1 7.0 7.5 8.0 8.6+PTX"

# get docker tag by image name
# arg1: BASE_IMAGE
# arg2: FINAL_IMAGE
# arg3: SRC_DIR_PYTORCH
define GetDockerTag
CUDA_VER=$(shell echo $(1) | awk -F'[/:-]' '{print $$2$$3}')
CUDNN_VER=$(shell echo $(1) | awk -F'[/:-]' '{print $$4}')
IMAGE_TYPE=$(shell echo $(2) | awk -F'[/:-]' '{print $$5}')
IMAGE_OS=$(shell echo $(1) | awk -F'[/:-]' '{print $$6}')
ifeq ($$(CUDA_VER),)
ERR=true
else ifeq ($$(CUDNN_VER),)
ERR=true
else ifeq ($$(IMAGE_TYPE),)
ERR=true
else ifeq ($$(IMAGE_OS),)
ERR=true
endif
ifneq ($$(ERR),)
$$(error cuda image format invalid)
endif
GIT_TAG=$(shell TAG=`git --work-tree=$(3) --git-dir=$(3)/.git describe --all | awk -F'/' '{print $$1}'`; if [ $$TAG == "heads" ]; then TAG=`git --work-tree=$(3) --git-dir=$(3)/.git describe --all --always --long --dirty | awk -F'/' '{print $$2}'`; else TAG=`git --work-tree=$(3) --git-dir=$(3)/.git describe --tags --always --dirty`; fi; echo $$TAG | sed 's/-/_/g')
DOCKER_TAG := $$(GIT_TAG)-$$(CUDA_VER)-$$(CUDNN_VER)-$$(IMAGE_OS)-$$(IMAGE_TYPE)
endef

# get git repo version
# arg1: VERSION_NAME
# arg2: SRC_DIR_PYTORCH
define GetRepoVersion
$(1)=$(shell TAG=`git --work-tree=$(2) --git-dir=$(2)/.git describe --all | awk -F'/' '{print $$1}'`; if [ $$TAG == "heads" ]; then TAG=`git --work-tree=$(2) --git-dir=$(2)/.git describe --all --always --long --dirty | awk -F'/' '{print $$2}'`; else TAG=`git --work-tree=$(2) --git-dir=$(2)/.git describe --tags --always --dirty`; fi; echo $$TAG)
endef

# get CUDA version
# arg1: CUDA_IMAGE_RUNTIME
define GetCUDAVersion
CUDA_VER=$(shell docker run -ti --rm $(1) bash -c "nvcc -V | grep release | awk -F'[ V]' '{print \$$NF}'")
endef

# get TORCH_CUDA_ARCH_LIST by image name
# arg1: BASE_IMAGE
define GetCudaArchList
CUDA_VER=$(shell echo $(1) | awk -F'[/:-]' '{print $$2$$3}')
ifeq ($$(CUDA_VER),)
$$(error cuda image format invalid)
endif
ifeq ($$(CUDA_VER),cuda10.1)
TORCH_CUDA_ARCH_LIST := $$(TORCH_CUDA_ARCH_LIST_10_1)
else ifeq ($$(CUDA_VER),cuda10.2)
TORCH_CUDA_ARCH_LIST := $$(TORCH_CUDA_ARCH_LIST_10_2)
else ifeq ($$(CUDA_VER),cuda11.0)
TORCH_CUDA_ARCH_LIST := $$(TORCH_CUDA_ARCH_LIST_11_0)
else ifeq ($$(CUDA_VER),cuda11.1)
TORCH_CUDA_ARCH_LIST := $$(TORCH_CUDA_ARCH_LIST_11_1)
endif
endef

PYTHON_VERSION   = 3.7
BUILD_PROGRESS   = auto
BUILD_ARGS       = --build-arg BASE_IMAGE=$(BASE_IMAGE) \
					--build-arg FINAL_IMAGE=$(FINAL_IMAGE) \
					--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
					--build-arg EXTRA_APT_PACKAGE=$(EXTRA_APT_PACKAGE) \
					--build-arg EXTRA_CONDA_PACKAGE=$(EXTRA_CONDA_PACKAGE) \
					--build-arg SRC_DIR_PYTORCH=$(SRC_DIR_PYTORCH) \
					--build-arg SRC_DIR_TORCHVISION=$(SRC_DIR_TORCHVISION) \
					--build-arg LIBTORCH_INSTALL_DIR=$(LIBTORCH_INSTALL_DIR) \
					--build-arg LIBTORCHVISION_INSTALL_DIR=$(LIBTORCHVISION_INSTALL_DIR) \
					--build-arg TORCH_CUDA_ARCH_LIST=$(TORCH_CUDA_ARCH_LIST)
DOCKER_LABELS	 = --label com.nvidia.cuda.version=$(CUDA_VER) \
					--label pytorch.version=$(PYTORCH_VER) \
					--label torchvision.version=$(TORCHVISION_VER)
DOCKER_BUILD     = DOCKER_BUILDKIT=1 docker build --progress=$(BUILD_PROGRESS) --target $(BUILD_TYPE) -t $(DOCKER_FULL_NAME):$(DOCKER_TAG) $(DOCKER_LABELS) $(BUILD_ARGS) .
DOCKER_PUSH      = docker push $(DOCKER_FULL_NAME):$(DOCKER_TAG)

.PHONY: all
all: cuda-devel-image cuda-runtime-image

.PHONY: push
push: cuda-devel-push cuda-runtime-push


.PHONY: cuda-devel-image
cuda-devel-image: BASE_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-devel-image: FINAL_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-devel-image: BUILD_TYPE := dev
cuda-devel-image:
	$(eval $(call GetDockerTag,$(BASE_IMAGE),$(FINAL_IMAGE),$(SRC_DIR_PYTORCH)))
	$(eval $(call GetCudaArchList,$(BASE_IMAGE)))
	$(eval $(call GetRepoVersion,TORCHVISION_VER,$(SRC_DIR_TORCHVISION)))
	$(eval $(call GetRepoVersion,PYTORCH_VER,$(SRC_DIR_PYTORCH)))
	$(eval $(call GetCUDAVersion,$(CUDA_IMAGE_DEVEL)))
	$(DOCKER_BUILD)

.PHONY: cuda-devel-push
cuda-devel-push: BASE_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-devel-push: FINAL_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-devel-push: BUILD_TYPE := dev
cuda-devel-push:
	$(eval $(call GetDockerTag,$(BASE_IMAGE),$(FINAL_IMAGE),$(SRC_DIR_PYTORCH)))
	$(eval $(call GetCudaArchList,$(BASE_IMAGE)))
	$(eval $(call GetRepoVersion,PYTORCH_VER,$(SRC_DIR_PYTORCH)))
	$(eval $(call GetRepoVersion,TORCHVISION_VER,$(SRC_DIR_TORCHVISION)))
	$(eval $(call GetCUDAVersion,$(CUDA_IMAGE_DEVEL)))
	$(DOCKER_PUSH)

.PHONY: cuda-runtime-image
cuda-runtime-image: BASE_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-runtime-image: FINAL_IMAGE := $(CUDA_IMAGE_RUNTIME)
cuda-runtime-image: BUILD_TYPE := official
cuda-runtime-image:
	$(eval $(call GetDockerTag,$(BASE_IMAGE),$(FINAL_IMAGE),$(SRC_DIR_PYTORCH)))
	$(eval $(call GetCudaArchList,$(BASE_IMAGE)))
	$(eval $(call GetRepoVersion,PYTORCH_VER,$(SRC_DIR_PYTORCH)))
	$(eval $(call GetRepoVersion,TORCHVISION_VER,$(SRC_DIR_TORCHVISION)))
	$(eval $(call GetCUDAVersion,$(CUDA_IMAGE_DEVEL)))
	$(DOCKER_BUILD)

.PHONY: cuda-runtime-push
cuda-runtime-push: BASE_IMAGE := $(CUDA_IMAGE_DEVEL)
cuda-runtime-push: FINAL_IMAGE := $(CUDA_IMAGE_RUNTIME)
cuda-runtime-push: BUILD_TYPE := official
cuda-runtime-push:
	$(eval $(call GetDockerTag,$(BASE_IMAGE),$(FINAL_IMAGE),$(SRC_DIR_PYTORCH)))
	$(eval $(call GetCudaArchList,$(BASE_IMAGE)))
	$(eval $(call GetRepoVersion,PYTORCH_VER,$(SRC_DIR_PYTORCH)))
	$(eval $(call GetRepoVersion,TORCHVISION_VER,$(SRC_DIR_TORCHVISION)))
	$(eval $(call GetCUDAVersion,$(CUDA_IMAGE_DEVEL)))
	$(DOCKER_PUSH)

.PHONY: clean
clean:
	-docker rmi -f $(shell docker images -q $(DOCKER_FULL_NAME))
