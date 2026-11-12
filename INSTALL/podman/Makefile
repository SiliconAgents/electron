ifndef PROJ_DATA_DIR
$(error PROJ_DATA_DIR is not set. Export it in ~/.bashrc before running make)
endif

# Root of the electron checkout passed into every image as a build arg so
# Containerfiles never hardcode a personal path.
ELECTRON_SRC ?= $(abspath ../..)

export XDG_DATA_HOME = $(PROJ_DATA_DIR)/
export XDG_DATA_DIRS = $(PROJ_DATA_DIR)/
export XDG_RUNTIME_DIR = /run/user/$(shell id -u)

build: clean
		podman build --build-arg ELECTRON_SRC=$(ELECTRON_SRC) -t pysparkcad -f ../UbuntuContainerFile
		podman save -o oci-pyspark.tar --format oci-archive localhost/pysparkcad
		apptainer build pysparkcad.sif docker-archive://oci-pyspark.tar

clean:
	rm -rf pysparkcad.sif oci-pyspark.tar

dpbuild:
	    podman build --net=host --build-arg ELECTRON_SRC=$(ELECTRON_SRC) -v $(PROJ_DATA_DIR):$(PROJ_DATA_DIR) -t testbuild -f ../dpContainerFile
		podman save -o oci-testbuild.tar --format oci-archive localhost/testbuild
		apptainer build --force testbuild.sif docker-archive://oci-testbuild.tar

run:
		 podman run -it --env DISPLAY --replace --net=host --name useroutside-userinside


spark:
	    podman build --net=host --build-arg ELECTRON_SRC=$(ELECTRON_SRC) -v $(PROJ_DATA_DIR):$(PROJ_DATA_DIR) -t pysparkbuild -f ../pysparkContainerFile
	    #podman build --net=host -v $(PROJ_DATA_DIR):$(PROJ_DATA_DIR) -t sparkbuild -f ../SparkContainerFile
		podman save -o oci-pysparkbuild.tar --format oci-archive localhost/pysparkbuild
		apptainer build --force pysparkbuild.sif docker-archive://oci-pysparkbuild.tar

# pysparkplusContainerFile is FROM localhost/pysparkcad, so the base has to
# exist.  Built only when missing, otherwise this would redo cudd and OpenSTA
# on every artemis build, which is the cost the layering avoids.
artemis:
	    podman image exists localhost/pysparkcad || $(MAKE) build
	    podman build --net=host --build-arg ELECTRON_SRC=$(ELECTRON_SRC) -v $(PROJ_DATA_DIR):$(PROJ_DATA_DIR) -t pysparkplusbuild -f ../pysparkplusContainerFile
		podman save -o oci-pysparkplusbuild.tar --format oci-archive localhost/pysparkplusbuild
		apptainer build --force pysparkplusbuild.sif docker-archive://oci-pysparkplusbuild.tar

# pysparkpp = pysparkplus plus qrouter.  Layered the same way artemis is, so
# the perl, CPAN, yosys and python stack is inherited rather than rebuilt.
# The parent is built only when missing.
#
# Point ELECTRON_CONTAINER at the .sif this produces and qroute finds qrouter
# without being told where it is.
sparkpp:
	    podman image exists localhost/pysparkplusbuild || $(MAKE) artemis
	    podman build --net=host --build-arg ELECTRON_SRC=$(ELECTRON_SRC) -v $(PROJ_DATA_DIR):$(PROJ_DATA_DIR) -t pysparkpp -f ../pysparkppContainerFile
		podman save -o oci-pysparkpp.tar --format oci-archive localhost/pysparkpp
		apptainer build --force pysparkpp.sif docker-archive://oci-pysparkpp.tar
