`benchmark_scripts`
===================

A collection of scripts that I use for profiling individual portions of the
ManageIQ application.  Though, because a lot of the scripts share the same
needs for profiling, application setup, etc., this ends up being more of a
library/framework.


Usage
-----

All of the scripts have an executable in the `bin/` dir, and available
flags/options can be found using the typical `-h/--help` flags.


### Common Options

* `-l, --loops`:   Number of times to run the test (to reduce variance)

Of note:  The profiler by default should attempt to clear out any records
created during the run, similar to the process in the tests.  This is an
attempt to make the tests runs as similar as possible, but in doing so does
drift away from how `production` works.

* `--db-strategy`: Set how the database is reset between runs

Strategies available are `"fixtures"` (default) and `"truncation"`.  The
`"fixtures"` strategy is the default strategy used by rails when doing tests,
and basically wraps all calls in a transaction.  The `"truncation"` strategy
simulates the `ActiveRecord` fixture strategy interface, but will instead
create a DB backup prior to running profiled run, and DB drop and restore to
that backup when the run is complete.

`truncation` should be faster and less invasive to the over profiling, so that
is something to consider.

* `--stackprof:`   Set `stackprof` as the profiler
* `--miqperf:`     Set `manageiq_performance` as the profiler

By default, `memory_profiler` is the default profiler.  Pass in `--stackprof`
or `--miqperf` to use one of those instead (one at a time only, though
`--miqperf` can use multiple under the hood).  Stackprof has a bunch of options
that can be passed to it, so see `-h` for more info (or the [`stackprof`
README](https://github.com/tmm1/stackprof#stackprof))

* `--clean-db`:    Drop, create, migrate and seed the DB prior to runs
* `--clean-logs:   Truncate the logs before starting the runs
* `--clean`:       Both of the above


Available Profilers
-------------------

### `stackprof`

Requires installing the gem yourself.   Most options available to the
`stackprof` profiler block are available via CLI flags.


### `memory_profiler`

Requires installing the gem yourself.   Most options available to the
`memory_profiler` profiler block are available via CLI flags.


### Parsing times from the EVM log

`Benchmark.measure`... basically...

We usually do some kind of `Benchmark.measure`/`Benchmark.realtime_block` in
our code base, and a lot of times already print it out to the logs.  In some of
the scripts, this is actually just parsed from the logs.  It isn't pretty, but
it avoids benchmarking already benchmarked code and introducing another layer
of profiling (though in this case, this should probably have next to no
impact).

This profiler will be used inconjunction with the other profiler in most scripts.


### Total Memory Used

Prints out the total memory at then of the process.

This profiler will be used inconjunction with the other profiler in most scripts.
