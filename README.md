# pytorch_docker
Build pytorch docker images. It's works on linux.


### Build images

1. git clone https://github.com/switch-st/pytorch_docker.git

2. cd pytorch_docker

3. sh init_torch.sh [`pytorch version`] [`pytorch git commit if needed`] [`torchvision git commit if needed`]

4. make


### Image Labels

```
docker inspect -f '{{json .Config.Labels}}' switchwang/pytorch:v1.7.0-cuda11.1-cudnn8-ubuntu18.04-devel

{
  "com.nvidia.cudnn.version": "8.0.4.30",
  "com.nvidia.volumes.needed": "nvidia_driver",
  "maintainer": "NVIDIA CORPORATION <cudatools@nvidia.com>"
}
```

| Label Name                   | Description             |
:----------------------------- |:----------------------- |
|`maintainer`                  | Maintainer of the image |


### Load images

- pytorch: v1.6.0, torchvision: v0.7.0, cuda: 10.2, cudnn: 7, devel images

    ``` shell
    docker pull switchwang/pytorch:v1.6.0-cuda10.2-cudnn7-ubuntu18.04-devel
    ```

- pytorch: v1.6.0, torchvision: v0.7.0, cuda: 10.2, cudnn: 7, runtime images

    ``` shell
    docker pull switchwang/pytorch:v1.6.0-cuda10.2-cudnn7-ubuntu18.04-runtime
    ```
