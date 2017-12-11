`miq_server_leak_discovery`
===========================

A collection of replication scripts and monitoring tools used in attempting to
figure out the cause of the leaking `MiqServer` process on an appliance.


Test scripts
------------

### `01_settings_loop_test.rb`

Runs a continual loop that will periodically fetch a `::Settings` value from
the appliance.

Results: Not leaking after running for a short while.


### `02_benchmark_realtime_block_loop_test.rb`

Runs a continual loop that will periodically run `Benchmark.realtime_block` and
call to a `noop`ing method.

Results: Not leaking after adding periodic `GC.start`s and running for a short
while.  Memory growth that was observed was not a leak, but the methods need to
keep track of a few values in memory (start/stop times, etc.)


### `03_heartbeat_loop_test.rb`

Loads up a bare minimal `Rails` environment, and periodically calls
`MiqServer#heartbeat`.  It will also run `GC.start` once every other minute, to
make sure that memory growth observed isn't just uncollected memory "yet to
happen `GC.start`".

Results:  Need more data.  Current tests have only happened on a `vagrant` VM.



Monitor Scripts
---------------

### `simple_memory_monitor.rb`

Takes a `PID` as an argument, and simply loops and reports on the memory every
5 seconds.


### `smaps_monitor.rb`

(Linux only)

A more advanced and detailed script that does the following:

* Takes a `PID` as an argument
* Every 5 seconds, it reads the `smaps` file for the process
* Stores a copy of the current hash generated from that file (indexed by line number)
* Compares the current version of the file with the last checked version
    - If they differ, print the diff
    - If they are the same, log that and continue on
* Prints the last 5 lines of the `evm.log` that contain `MiqServer` work.


