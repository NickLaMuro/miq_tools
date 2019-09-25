RSpec Profiling Tools
=====================

Adds a collection of scripts that you can include via `RUBYOPT=` to profile
rspec examples and startup for `manageiq`.  This will probably be broken out in
the future, but for now, this works.

Requires that stackprof is installed via rubygems:

```console
gem install stackprof
```


`rspec_example_profiler`
------------------------

Wraps each example with a `StackProf.start`, capturing as much as possible in
regards to the `before`/`after` hooks, as well as the example itself to
determine what parts are consuming the most time.

### Usage

```console
RUBYOPT="-I. -rrspec_example_profiler" bundle exec rspec spec/models/metric/ci_mixin/capture_spec.rb
```


`rspec_benchmark_setup`
-----------------------

Benchmarks, starting as early in the ruby process as possible, up until rspec
starts loading and running the first spec.

### Usage

```console
RUBYOPT="-I. -rrspec_benchmark_setup" bundle exec rspec spec/models/metric/ci_mixin/capture_spec.rb
```
