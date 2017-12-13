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


### `04_yaml_dump_loop_test`

Tests part of `$log.log_hashes` which dumps the settings to a hash.

Results:  The C based part of YAML dump made it suspect and since we have
determined that this is most likely something that ruby isn't aware of (by
studying the smaps over time), it seemed possible this could be the cause.

But after further analyzing the codebase, this portion isn't reached on a
regular basis, which doesn't match the steady increase of memory every 10 min
or so that has been observed.  Also, it didn't really leak... so...


### `05_miq_server_sync_needed_loop_test`

Test the `sync_needed?` portion of the monitor loop, which is a part of
`MiqServer#monitor_workers`.


Results:  Currently showing a small bit of promise in being at least a cause of
the leak, but even if it does leak, seems like it is only a part of it, since
it only leaks on a large interval (every hour or so).


### `06_my_server_clear_cache_loop_test`

Test the global variable usage/clearing of the `cache_with_timeout` code to see
if it might be the cause of the leak.


Results:  Doesn't seem like it


### `07_kill_workers_due_to_resources_exhausted_loop_test`

Test the code that is called with `kill_workers_due_to_resources_exhausted?`
method, since it does some file reading, and is executed semi regularly.


Results:  Doesn't seem like it


### `08_drb_heartbeat_loop_simulation_test`

Test the DRb server/client heartbeat workflow, in the smallest possible form.


Results:  Doesn't seem like it, but this one was a pain to try and get right,
so I might have screwed something up.



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


