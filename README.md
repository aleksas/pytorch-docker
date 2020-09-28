# pytorch_docker
Build pytorch docker images. It's works on linux.


### Build images

1. git clone https://github.com/switch-st/pytorch_docker.git

2. cd pytorch_docker

3. sh init_torch.sh [`pytorch version`]

4. make


### Load images

- pytorch v1.6.0, vision v0.7.0, cpu, devel images

    ``` shell
    docker pull switchwang/pytorch:v1.6.0_cpu-devel
    ```

- pytorch v1.6.0, vision v0.7.0, cpu, runtime images

    ``` shell
    docker pull switchwang/pytorch:v1.6.0_cpu-runtime
    ```

- pytorch v1.6.0, vision v0.7.0, gpu, devel images

    ``` shell
    docker pull switchwang/pytorch:v1.6.0_cuda-devel
    ```

- pytorch v1.6.0, vision v0.7.0, gpu, runtime images

    ``` shell
    docker pull switchwang/pytorch:v1.6.0_cuda-runtime
    ```

- pytorch v1.5.0, vision v0.6.0, cpu, devel images

    ``` shell
    docker pull switchwang/pytorch:v1.5.0_cpu-devel
    ```

- pytorch v1.5.0, vision v0.6.0, cpu, runtime images

    ``` shell
    docker pull switchwang/pytorch:v1.5.0_cpu-runtime
    ```

- pytorch v1.5.0, vision v0.6.0, gpu, devel images

    ``` shell
    docker pull switchwang/pytorch:v1.5.0_cuda-devel
    ```

- pytorch v1.5.0, vision v0.6.0, gpu, runtime images

    ``` shell
    docker pull switchwang/pytorch:v1.5.0_cuda-runtime
    ```
