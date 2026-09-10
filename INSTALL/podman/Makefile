export XDG_DATA_HOME = /proj_pd/user_dev/rsrivastava/
export XDG_DATA_DIRS = /proj_pd/user_dev/rsrivastava/

build: clean
		podman build -t pysparkcad -f ../UbuntuContainerFile
		podman save -o oci-pyspark.tar --format oci-archive localhost/pysparkcad
		apptainer build pysparkcad.sif docker-archive://oci-pyspark.tar

clean:
	rm -rf pysparkcad.sif oci-pyspark.tar 

dpbuild:
	    podman build --net=host -v /proj_pd/user_dev/rsrivastava:/proj_pd/user_dev/rsrivastava -t testbuild -f ../dpContainerFile
		podman save -o oci-testbuild.tar --format oci-archive localhost/testbuild
		apptainer build --force testbuild.sif docker-archive://oci-testbuild.tar

run:
		 podman run -it --env DISPLAY --replace --net=host --name useroutside-userinside


spark:
	    podman build --net=host -v /proj_pd/user_dev/rsrivastava:/proj_pd/user_dev/rsrivastava -t pysparkbuild -f ../pysparkContainerFile
	    #podman build --net=host -v /proj_pd/user_dev/rsrivastava:/proj_pd/user_dev/rsrivastava -t sparkbuild -f ../SparkContainerFile
		podman save -o oci-pysparkbuild.tar --format oci-archive localhost/pysparkbuild
		apptainer build --force pysparkbuild.sif docker-archive://oci-pysparkbuild.tar

# pysparkplusContainerFile is FROM localhost/pysparkcad, so the base has to
# exist.  Built only when missing, otherwise this would redo cudd and OpenSTA
# on every artemis build, which is the cost the layering avoids.
artemis:
	    podman image exists localhost/pysparkcad || $(MAKE) build
	    podman build --net=host -v /proj_pd/user_dev/rsrivastava:/proj_pd/user_dev/rsrivastava -t pysparkplusbuild -f ../pysparkplusContainerFile
		podman save -o oci-pysparkplusbuild.tar --format oci-archive localhost/pysparkplusbuild
		apptainer build --force pysparkplusbuild.sif docker-archive://oci-pysparkplusbuild.tar
