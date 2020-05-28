# [dralois/blender-module-builder](https://hub.docker.com/r/dralois/blender-python-module-builder) (Forked from [here](https://hub.docker.com/r/mattiasohlsson/centos-blender-builder/))

## Description

This docker container builds Blender 2.82a as a python module, using CentOS 7 & devtoolset 6 (same as the official builds). The container comes completely setup for this task and compiles a portable version of Blender as a python module for Linux, able to be used on most distributions. The only requirement on the target system is python 3.7 (3.6 may work..), as the newest versions (>= 3.8) will segmentation fault on import. This container can optionally also build Appleseed 2.1.0 with python 3 bindings, which is required for the Blender addon. The Appleseed build script automatically downloads & builds Blenderseed and stores the addon in the output directory (/root/build). This step has to be invoked manually within the container.

## Usage

### Automatic build

```docker
docker run --storage-opt size=35G dralois/blender-python-module-builder
```

### Manual build

```docker
docker run -it --storage-opt size=35G dralois/blender-python-module-builder bash
```

Then, either run the automatic build script

```bash
# Builds deps, bpy
sh /usr/bin/build.sh
```

Or build manually (-> Other builds are possible too!)

```bash
# 1) Go to Blender's source dir
cd root/blender-git/

# 2a) For shared builds (faster, not portable):
sh ./build_files/build_environment/install_deps.sh --with-all --build-all
# 2b) For static builds (slower, portable):
make deps

# 3) Build Blender of your choice (bpy needs to be built without jemalloc!)
make [full] [lite] [bpy BUILD_CMAKE_ARGS="-D WITH_MEM_JEMALLOC=OFF"]
```

### Appleseed + Blenderseed build

The Blender dependencies have to have been built already for the script to work, as building Blenderseed requires the static python version built for Blender. If this is the case, boost python (1.61.0) is built using that python version and linked when building Appleseed. This python 3 version is linked as well, which allows to generate the required python 3 bindings.

```bash
# Builds appleseed & blenderseed
sh /usr/bin/appleseed.sh
```

## Source Repo

[dralois/bpy-builder](https://github.com/dralois/Blender-Python-Module-Docker) forked from [here](https://github.com/mattias-ohlsson/docker-centos-blender-builder)
