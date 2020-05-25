# [dralois/bpy-builder](https://hub.docker.com/r/dralois/blender-python-module-builder) (Forked from [here](https://hub.docker.com/r/mattiasohlsson/centos-blender-builder/))

## Description

This docker container builds blender 2.83 as a python module. It is completely configured and setup for this task and able to compile a portable version that should work on most Linux distributions. The only requirement is python 3.6 / 3.7, as more recent versions will seg fault.

## Usage

### Automatic build

```docker
docker run --storage-opt size=25G dralois/blender-python-module-builder
```

### Manual build

```docker
docker run -it --storage-opt size=25G dralois/blender-python-module-builder bash
```

Then, either run the automatic builder

```bash
# Builds deps, bpy
sh /usr/bin/build.sh
```

Or build manually (-> "Normal" builds are possible too!)

```bash
# Enable correct compilers etc.
scl enable devtoolset-7 bash
# Go to source dir
cd root/blender-git/

# For local, non-static builds (faster):
sh ./build_files/build_environment/install_deps.sh --with-all --build-all
# For portable, static builds (slower):
make deps

# Make Blender of your choice (bpy needs to be built without jemalloc)
make [full] [lite] [bpy BUILD_CMAKE_ARGS="-D WITH_MEM_JEMALLOC=OFF"]
```

## Source

[dralois/bpy-builder](https://github.com/dralois/Blender-Python-Module-Docker) forked from [here](https://github.com/mattias-ohlsson/docker-centos-blender-builder)
