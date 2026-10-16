# Build and run the Q3 server in a container

The [Containerfile](../Containerfile) runs the same `scripts/build-q3.sh` as the
[manual installation](q3-quickstart.md#manual-installation-download-and-build),
on CUDA 13.4 with GCC 15, and starts the server with `scripts/serve-q3.sh`.
It works with Podman or Docker. This is a packaging convenience: the container
build has not been benchmarked, and the measured builds used CUDA 13.3.

## Requirements

- Linux x86-64 host with an NVIDIA driver that supports CUDA 13.4.
- The NVIDIA Container Toolkit, with CDI configured for Podman
  (`nvidia-ctk cdi generate`) or the runtime configured for Docker.
- The model and chat template on the host, downloaded with
  `./scripts/download-q3.sh` into `models/`.

## Build

Build on the machine that will serve. `GGML_NATIVE` stays on, so the CPU
kernels target the CPU that runs the build, as in every measured build.

```bash
podman build -t routeweaver-q3 .
```

Build arguments:

| Argument | Default | Meaning |
|---|---|---|
| `Q3_VARIANT` | `candidate` | `candidate`, `baseline` or `fast`, as for `build-q3.sh`. |
| `CUDA_ARCHITECTURES` | `86` | GPU compute capability. No GPU is visible during a build, so `native` does not work. |
| `BUILD_JOBS` | `1` | Parallel compile jobs. Raise it if you have the RAM. |

For example, the Fast variant with four jobs:

```bash
podman build -t routeweaver-q3-fast --build-arg Q3_VARIANT=fast --build-arg BUILD_JOBS=4 .
```

## Run

Stop other GPU model servers first. The launcher binds to `127.0.0.1`, so the
container uses host networking to stay reachable on the host's loopback only.

```bash
podman run --rm --device nvidia.com/gpu=all --network host -v "$PWD/models:/opt/routeweaver/models:ro,Z" routeweaver-q3
```

With Docker, use `--gpus all` instead of `--device nvidia.com/gpu=all`.

The launcher's environment settings pass through with `-e`, for example
`-e CONTEXT=131072` or `-e PORT=8081`. For vision with the candidate variant,
download the projector with `./scripts/download-q3.sh --vision-only` and add
`-e MMPROJ_PATH=/opt/routeweaver/models/mmproj-F16.gguf`. Pass `--print-config`
after the image name to print the server command line without starting it.

The server checks the model's SHA-256 on every start, so allow some time
before it begins loading.

The image holds only the server and launcher. Run `scripts/check-q3.sh`,
benchmarks and `routeweaver setup` from a normal checkout.
