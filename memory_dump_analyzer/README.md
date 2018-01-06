## DON'T USE!

Honestly, you should just use https://github.com/Fryguy/memory_analyzer for
this.  I am including this here since it has some features that aren't in
that project (yet in some cases), or some slight tweaks and things I have found
that you can do in ruby that are neat, and worth having archived publicly.

Even still, the `memory_analyzer` project is much more refined, faster, and
feature rich, so not real reason to use what I have here.  Any features I have
here that don't exist in there I plan to eventually port to that project.


memory_dump_analyzer
--------------------

This is a adaptation of some of the `ObjectSpace.dump_all` analysis scripts
found in Sam Saffron's article on "Debugging memory leaks in Ruby":

https://samsaffron.com/archive/2015/03/31/debugging-memory-leaks-in-ruby


The input files are also generated in a similar fashion that is described in
the blog post:

```ruby
io=File.open("/tmp/my_dump", "w")
ObjectSpace.dump_all(output: io); 
io.close
```

And assumes that you are currently running with
`ObjectSpace.trace_object_allocations_start` (see the post for more details).

That said, this script supports working with gzipped files, which is highly
recommend that you zip up the output files that you do dump, as they are quite
large (500MB a piece in my case).  


Usage:
------

There are three modes for the script:

### Summary

Without any flag, the script will keep track of all object allocations and
print out the counts, grouped by `GC` generation.


### Specific generation analysis

The `-g`/`--generation` flag allows for displaying the more verbose output
described in the post, which displays the counts of the currently allocated
objects for a specific generation, grouped by line and line number.


### Interactive

The `-i`/`--interactive` flag allows you to consume the memory dump, and then
open an IRB session with accessible for custom analysis.
