# Builds the Q3 llama-server with scripts/build-q3.sh and runs it with
# scripts/serve-q3.sh. See docs/container.md for build and run commands.
#
# By default the CPU kernels target the machine running the image build, as in
# every measured build, so build on the machine that will serve. To build
# elsewhere, set CPU_ARCH to the serving CPU's -march value.

ARG CUDA_BUILDER=docker.io/nvidia/cuda:13.4.2-devel-ubuntu26.04@sha256:14fd494fd8496817a70700e4d2c52bd42de56c5d39c041bf8342814614d5fe56
ARG CUDA_RUNTIME=docker.io/nvidia/cuda:13.4.2-runtime-ubuntu26.04@sha256:761af29727cf549d7938c7cbdce1e6fbf114a96dfbb799ac747395675d2b18f7

FROM ${CUDA_BUILDER} AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates cmake curl g++-15 gcc-15 libssl-dev ninja-build patch \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/routeweaver
# The whole tree is copied because build-q3.sh verifies it against SHA256SUMS.
COPY . .
ARG Q3_VARIANT=candidate
# No GPU is visible while building, so "native" CUDA detection cannot work.
# 86 is the tested RTX 3060; set it to your GPU's compute capability.
ARG CUDA_ARCHITECTURES=86
ARG BUILD_JOBS=1
ARG CPU_ARCH=native
# libggml-cuda needs the driver's libcuda.so.1, which only exists at run time.
# Link without it, and give the script's final --version check the toolkit stub.
RUN mkdir /tmp/cuda-stub \
    && ln -s /usr/local/cuda/lib64/stubs/libcuda.so /tmp/cuda-stub/libcuda.so.1 \
    && Q3_VARIANT="$Q3_VARIANT" CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES" BUILD_JOBS="$BUILD_JOBS" CPU_ARCH="$CPU_ARCH" \
    CUDA_TOOLKIT_ROOT=/usr/local/cuda CC=gcc-15 CXX=g++-15 \
    LDFLAGS=-Wl,--allow-shlib-undefined LD_LIBRARY_PATH=/tmp/cuda-stub \
    ./scripts/build-q3.sh

FROM ${CUDA_RUNTIME}
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 libssl3t64 \
    && rm -rf /var/lib/apt/lists/*
ARG Q3_VARIANT=candidate
# Listen on the container's interfaces; publish the port to choose who can reach it.
ENV Q3_VARIANT=${Q3_VARIANT} CUDA_TOOLKIT_ROOT=/usr/local/cuda BIND_ADDRESS=0.0.0.0
WORKDIR /opt/routeweaver
COPY --from=build /opt/routeweaver/scripts/q3-env.sh /opt/routeweaver/scripts/serve-q3.sh scripts/
COPY --from=build /opt/routeweaver/build/q3-${Q3_VARIANT}/bin build/q3-${Q3_VARIANT}/bin
# Mount the directory populated by scripts/download-q3.sh here, read-only.
VOLUME /opt/routeweaver/models
USER ubuntu
EXPOSE 8080
ENTRYPOINT ["/opt/routeweaver/scripts/serve-q3.sh"]
