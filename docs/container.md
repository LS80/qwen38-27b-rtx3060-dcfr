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

Build on the machine that will serve. By default the CPU kernels target the
CPU that runs the build, as in every measured build. To build somewhere else,
set `CPU_ARCH` to the serving CPU's GCC `-march` value.

```bash
podman build -t routeweaver-q3 .
```

Build arguments:

| Argument | Default | Meaning |
|---|---|---|
| `Q3_VARIANT` | `candidate` | `candidate`, `baseline` or `fast`, as for `build-q3.sh`. |
| `CUDA_ARCHITECTURES` | `86` | GPU compute capability. No GPU is visible during a build, so `native` does not work. |
| `BUILD_JOBS` | `1` | Parallel compile jobs. Raise it if you have the RAM. |
| `CPU_ARCH` | `native` | `native` targets the build machine's CPU. Otherwise a GCC `-march` value such as `raptorlake`, for the CPU that will serve. |

For example, the Fast variant with four jobs:

```bash
podman build -t routeweaver-q3-fast --build-arg Q3_VARIANT=fast --build-arg BUILD_JOBS=4 .
```

## Published images

[`.github/workflows/container-image.yml`](../.github/workflows/container-image.yml)
builds `candidate` and `fast` images on GitHub Actions and publishes them to
`ghcr.io/<owner>/qwen38-27b-rtx3060-dcfr`. They target one machine rather than
the runner: an i5-14500 (`CPU_ARCH=raptorlake`, which also suits Alder Lake) with
an RTX 3060 (`CUDA_ARCHITECTURES=86`). On a CPU without AVX-VNNI they can stop
with an illegal-instruction error, so build locally instead.

Tags are `<ref>-<variant>-raptorlake-sm86`, where `<ref>` is the branch, the
version without its `v` prefix, `sha-<commit>`, or `latest` for the default branch.
For example:

```bash
podman pull ghcr.io/<owner>/qwen38-27b-rtx3060-dcfr:latest-candidate-raptorlake-sm86
```

These builds have not been benchmarked. Compare them with a native build using
the [benchmark steps](q3-quickstart.md#validate-and-benchmark) before relying on
their speed.

## Run

Stop other GPU model servers first. Inside the container the launcher listens
on all interfaces (`BIND_ADDRESS=0.0.0.0`), and the published port decides who
can connect. Publishing on `127.0.0.1` keeps the API reachable from this machine
only, as a local `serve-q3.sh` run is.

```bash
podman run --rm --device nvidia.com/gpu=all -p 127.0.0.1:8080:8080 -v "$PWD/models:/opt/routeweaver/models:ro,Z" routeweaver-q3
```

With Docker, use `--gpus all` instead of `--device nvidia.com/gpu=all`.

The API is then `http://127.0.0.1:8080/v1`. To use another host port, change
only the first number, for example `-p 127.0.0.1:8094:8080`. If you set
`-e PORT`, publish that container port instead. Use `-p 8080:8080` only if other
machines on your network should reach the server, because the API has no
authentication.

The launcher's environment settings pass through with `-e`, for example
`-e CONTEXT=131072` or `-e THREADS=8`. For vision with the candidate variant,
download the projector with `./scripts/download-q3.sh --vision-only` and add
`-e MMPROJ_PATH=/opt/routeweaver/models/mmproj-F16.gguf`. Pass `--print-config`
after the image name to print the server command line without starting it.

The server checks the model's SHA-256 on every start, so allow some time
before it begins loading.

The image holds only the server and launcher. Run `scripts/check-q3.sh`,
benchmarks and `routeweaver setup` from a normal checkout.
