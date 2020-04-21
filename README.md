MIQ Tools
=========

A collection of scripts and tools I use to debug and analyze the performance of
MIQ/CFME.  Most of these tools should be written in ruby with minimum
dependencies required beyond what is available in ruby's standard library.

Other gems/tools you might need for full functionality of some of the tools:

* `stackprof`       (rubygem)
* `memory_profiler` (rubygem)
* `gnuplot`         (cli tool)

A lot of this is just self documentation for myself to look back to, and git
these scripts off my current workstation, but you are free to use and
distribute these yourself if you find them useful.  Linking back to this repo
would be nice, but not required.


Misc. Tips
----------

Random tips that I have found incredibly useful that don't hold a specific
place.  I take no credit for any of these, and most likely these have come from
some tip on stackoverflow or similar search result.

### Reading compressed logs

Since the uncompressed log dumps from an appliance can be quite large, one way
to read from the gzip directly in a terminal `PAGER` (like `less`) is to pipe
directly from `gunzip` using the `-c` flag, which outputs it to `STDOUT`.  So
something like the following:

```console
$ gunzip -c log/evm.log-20000101.gz | less
```

If you prefer to use your editor, such as `vim`, you can do that as well, but
there is a catch.  Vim, at least in the versions I am familiar with, can not
take STDOUT as an argument, so you have to pass it in as a tmp file.  You can
do this in bash doing the following:

```console
$ vim -n <(gunzip -c log/evm.log-20000101.gz)
```

The `-n` flag is used to tell Vim to not create a swap file, since tmp files
tend to share a file descriptor, and it will complain if you try to open
another vim session in the same directory (or of you have a shared swap
directory).

The command inside of the `<(...)` can include any stream parsing as well, so
you can target a specific PID in there as well:

```console
$ vim -n <(gunzip -c log/evm.log-20000101.gz | grep "#1234")
```

Same goes for the `less` variant.
