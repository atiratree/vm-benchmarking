## Benchmarking Guide

### Optional Settings
1. Set these env variables or customize defaults in `bin/config.env` 
   - LIBVIRT_DEFAULT_URI
   - DISTRO: is just for naming vms
   - VERBOSE_FILE: set to `/dev/tty` to see verbose output, all the verbose output will be still logged

### Setup

`cd benchmarking`

#### Creating Base VM
1. Install base vm for all benchmarks and start it
2. run `./bin/init-base-image.sh "$VM_NAME"`
3. fill in the root password when asked

#### Preparing benchmarks
1. `cp benchmarks/benchmarks-images.cfg{.example,}`
2. customize `benchmarks-images.cfg` 
   - select benchmarks to initialize
   - fill in the name of the base image
3. for each benchmark you want to initialize
   - `cp benchmarks/$BENCHMARK_NAME/settings.env{.example,}`
   - `cp benchmarks/$BENCHMARK_NAME/install-$INSTALL_VERSION/settings.env{.example,}`
   - customize each settings.env
4. run `./bin/prepare-benchmark-images.sh`
5. check `benchmarks/$BENCHMARK_NAME/install-$INSTALL_VERSION/out/output` for any errors

### Benchmarking
1. `cp benchmarks/benchmark-suite.cfg{.example,}`
2. customize `benchmarks-suite.cfg` 
   - remove `CLEAN_FLAG=clean` to save intermediate results and resource usage (which are used for analysis)
   - set `NO_OUTPUT_CHECK_MIN` to check responsiveness of benchmarks 
   (use only if there is a chance the benchmark will stop responding).
    This prevents benchmark suite coming to a halt.
   - set `MEASURE_RESOURCE_USAGE=yes` to inject sysstat into the vm and measure resource usage
3. for each benchmark run
   - `cp benchmarks/$BENCHMARK_NAME/install-$INSTALL_VERSION/run-$RUN_VERSION/settings.env{.example,}`
   - customize each settings.env if it exists
4. run `./bin/prepare-benchmark-images.sh`
5. see `benchmarks/$BENCHMARK_NAME/install-$INSTALL_VERSION/run-$RUN_VERSION/analysis` and `out` for results
