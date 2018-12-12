## VM Benchmarking

VM Benchmarking is a test suite used to evaluate performance of VMs on [libvirt](https://libvirt.org/).
It contains a collection of scripts that can test predefined benchmarks:

- Compression (uses [pbzip2](https://launchpad.net/pbzip2) and [pigz](https://github.com/madler/pigz))
- [NPB (NAS Parallel Benchmarks)](https://www.nas.nasa.gov/publications/npb.html)
- [PostgresSQL](https://wiki.postgresql.org/wiki/Pgbenchtesting)
- [Wildfly Testsuite](https://github.com/wildfly/wildfly/tree/master/testsuite)
- [Apache DayTrader](http://geronimo.apache.org/GMOxDOC20/daytrader.html) used together with [Apache JMeter](https://jmeter.apache.org/)


These benchmarks can be further configured and run in batches.
Please look at the [benchmarking guide](https://github.com/suomiy/vm-benchmarking/tree/master/benchmarking) for more details.

Testing needs a predefined fully installed VM which will be then cloned, and initialized with a desired benchmark.
SSH connection is then used to run and monitor these images while benchmarking.

It is possible to specify different testing scenarios, settings and libvirt.xml for the runs (scripts in `./benchmarking/bin/bench/setup`)

#### Test steps:
           
- Clone VM and its disk.
- Compile test run script with benchmark specific and global settings.
- Compile auxiliary test run script (optional and only used by Apache DayTrader when starting Apache JMeter).
- Set swappiness to 0 and clear swap.
- Flush file system buffers.
- Clear page cache, dentries and inodes.
- Flush disk hardware buffers.
- Apply test's libvirt XML to the VM's definition.
- Start the VM.
- Start auxiliary VM (optional).
- Run test script on the VM.
- Run auxiliary test script on auxiliary VM (optional).
- Wait for benchmark to finish.
- Gather and save results.
- Delete the VMs.

#### Measuring Performance

Measuring of performance and plotting graphs can be configured and is done with the help of [sysstat](https://github.com/sysstat/sysstat)


#### Results

There is already a directory with results from 2 machines. These can be safely deleted.
