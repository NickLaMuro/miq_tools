Troubleshooting
---------------

> Q.  I am getting errors trying to run `bin/rake update:ui`.  A bunch of stuff
> about `graphql` and junk.  HALP!

This (unfortunately is a bit of a common problem that isn't solved by
`bisect_gemfile_parser` in the slightest.

Things that have worked for me in the past (YMMV) is running the following
(regardless of error):

```console
$ rm bundler.d/bisect.rb
$ git checkout master
$ bin/update
$ git checkout -
$ bin/bisect_gemfile_parser
$ bin/bundle update
$ bin/rake update:ui
```

Instead of running `bin/update` alone.  What the above does is at least toss
some `packs` into the `public/packs` directory so that you have something for
Rails' javascript tags to resolve to, and then hopefully you have a way of
requesting the page you need without relying heavily on the javascript assets.

I personally use `benchmark` command `manageiq-performance` to hit a specific
route:

```console
$ bundle exec miqperf benchmark /route/you/want/to/hit
```

Setup instructions found here: https://github.com/ManageIQ/manageiq-performance

There is a good chance that the login page will still function doing this
method, and if the page hits an error in the controller, then the assets are
not going to be a problem.

More so, if you are hitting an API route, the assets won't matter, so you can
just run the above command with the `--api` flag:

```console
$ bundle exec miqperf benchmark --api /api/route/you/want/to/hit
```


> Q. I am getting gem dependency resolution errors!  HALP!!1!

Unfortunately, this is where you have to get your hands dirty and resolve the
conflict yourself.  Also, you can yell at the dev that caused this later (I
give you permission), because it is definitely frustrating.

So the issue here usually is that some dependency in X repo got updated, but
the same dependency in Y repo is locked at a different version, and a PR to fix
the issue was then created in between the SHA you are currently at and the time
that issue was resolved with a PR.

The easiest way to resolve the conflict is sometimes to simply remove the
dependency from the `Gemfile` by commenting it out.  This is an example of that
kind of error that I resolved using this method:


```console
$ bin/bundle update
Fetching https://github.com/ManageIQ/handsoap.git
...
Fetching https://github.com/ManageIQ/manageiq-gems-pending.git
Fetching gem metadata from https://rubygems.org/..........
Fetching version metadata from https://rubygems.org/...
Fetching dependency metadata from https://rubygems.org/..
Resolving dependencies.........................
Bundler could not find compatible versions for gem "faraday":
  In Gemfile:
    manageiq-providers-google x86_64-darwin-15 was resolved to 0.1.0, which depends on
      google-api-client (= 0.8.6) x86_64-darwin-15 was resolved to 0.8.6, which depends on
        googleauth (~> 0.3) x86_64-darwin-15 was resolved to 0.6.2, which depends on
          faraday (~> 0.12)

    manageiq-providers-kubernetes was resolved to 0.1.0, which depends on
      prometheus-alert-buffer-client (~> 0.2.0) x86_64-darwin-15 was resolved to 0.2.0, which depends on
        faraday (~> 0.9.2)

Bundler could not find compatible versions for gem "rbvmomi":
  In Gemfile:
    manageiq-providers-vmware was resolved to 0.1.0, which depends on
      rbvmomi (~> 1.11.3)

    manageiq-providers-vmware was resolved to 0.1.0, which depends on
      vmware_web_service (~> 0.2.6) was resolved to 0.2.11, which depends on
        rbvmomi (~> 1.12.0)
```

For this, I just commented out both `manageiq-providers-google` and
`manageiq-providers-vmware` in the `Gemfile` directly, since I didn't need them
for what I was testing.  If this is a `manageiq_plugin` gem, then make sure you
are also removing it from the `bundler.d/bisect.rb` file so that doesn't break
`bundle update`.

The above assumes the plugin in question isn't needed for you to confirm your
bug.  If it is, then you might have to do some tweaks in the Gemfile directly
to lock versions of the offending gems.  For the above to fix `rbvmomi`, you
might be able to explicitly set it to something that works for both
`vmware_web_service` and `manageiq-providers-vmware`, or explicitly define a
version of `vmware_web_service` that doesn't have such a hard requirement.
