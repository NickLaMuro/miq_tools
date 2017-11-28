Memory Leak Logging Additions for a MIQ/CFME appliance
======================================================

The first part of this code is to enrich the appliance logs with more specific
memory and `GC` information, helpful for determining the current status of the
process.  Also, on an occasional basis, there code in place to do a memory dump
of the current process and write it to a file in the tmp directory for specific
workers (though, this could be easily applied to any worker, since the code is
relatively generic).

The other portion of this code is log analysis, which will take the enriched
logs (gzipped form acceptable as well), and process them into a form that
`gnuplot` can digest, and then use a `gnuplot` script to plot the data.


Usage
-----

1. Apply the diffs to an appliance.  The following files should receive the
   changes:
    - manageiq-providers-vmware/app/models/manageiq/providers/vmware/infra_manager/metrics_collector_worker/runner.rb
    - app/models/miq_ems_metrics_processor_worker/runner.rb
    - app/models/miq_queue_worker_base/runner.rb
   
2. Restart the appliance:  `sudo systemctl restart evmserverd`
   
3. Let the appliance run for a lengthy period of time.
    - Periodically, it will be good to run the following to compress the dumps:
      
      ```console
      $ vmdb
      $ ls tmp/*.dump | xargs gzip
      ```
      
4. After time has passed, `scp` down the logs from `/var/www/miq/vmdb/logs` and
   the dumps in `/var/www/miq/vmdb/tmp`.
   
5. Run the `evm_mem_log_processor.rb` from this dir.  Something like:
   
   ```console
   $ ruby memory_leak_worker_logging/evm_mem_log_processor.rb --worker-type=".*MetricsCollectorWorker::Runner" evm.log-2017*
   ```
   
6. Run the outputed data through the `gnuplot` script:
   
   ```console
   $ memory_leak_worker_logging/plot_worker_memleak_data.gnup tmp/20170101_1234.data tmp/20170101_1234.impulses
   ```
   
   And a graph should be outputted to `tmp/20170101_1234.png` (or `.svg`, if
   configured to use that).


### Addition Graph Usage Info

By default, the `plot_worker_memleak_data.gnup` script will plot all of the
data found in the `.data` file provided (and `.impulses` file, if provided).

If desired, you can also plot a specific time range from a certain point by
appending a datetime string to the end of the command:

```console
$ plot_worker_memleak_data.gnup tmp/20170101_1234.data tmp/20170101_1234.impulses "2017-01-01T12:00:00"
```

Or, you can include an end time as well:

```console
$ plot_worker_memleak_data.gnup tmp/20170101_1234.data tmp/20170101_1234.impulses "2017-01-01T12:00:00" "2017-01-02T12:00:00"
```


The output filenames will then include the from timestamp and to timestamp (if
provided) to designate the range of the data plotted.


```
20170101_1234_from_20170101120000.png
20170101_1234_from_20170101120000_to_20170102120000
```
