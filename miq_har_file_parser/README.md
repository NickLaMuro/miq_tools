`miq_har_file_parser`
=====================

This is a script that is used for parsing data from a HAR (**H**ttp
**AR**chive) to either print a summary of requests made, or generate a `rails
runner` script that can auto execute the steps previously run, with an option
to enable profiling via `manageiq-performance` (requires the gem to be running
in the application environment).

This also automatically filters out invalid requests for profiling (assets, api
pings, etc.)


Request Summary
---------------

Prints a summary of the requests made, the type of request (GET, POST, etc.),
and the time the request took to process (from the browser's perspective):

```console
$ miq_har_file_parser/cli.rb print my_example_requests.har
454     POST    https://localhost:3000/dashboard/authenticate
767     GET     https://localhost:3000/dashboard/show
10007   GET     https://localhost:3000/catalog/explorer
2730    POST    https://localhost:3000/catalog/explorer?page=2&id=
3500    POST    https://localhost:3000/catalog/explorer?page=3&id=
```


Script Generator
----------------

Generates a ruby script that can be used in conjunction with `rails runner` to
reproduce a given set of requests parsed from a HAR file (requests to be
executed will match what is outputted in order from the `print` subcommand).


```console
$ miq_har_file_parser/cli.rb print -o request_runner.rb my_example_requests.har
$ cat request_runner.rb
```

```ruby
# FILE:  request_runner.rb

# Setup code
Rails.application.load_console
Rails.env = ENV["RAILS_ENV"]

# Include helper methods and call
include Rails::ConsoleMethods
toggle_console_sql_logging

# Avoid errors from UI worker (included in console, but not in runner...)
MiqUiWorker.preload_for_console

CSRF_TOKEN_REGEXP = /.*csrf-token.*content="(?<CSRF_TOKEN>[^"]*)"/

# Intialize base headers
#
# Update any request's `:headers => base_headers` to use
# `benchmark_headers` if you wish to profile the request.
base_headers      = {}
perf_headers      = { 
  "HTTP_WITH_PERFORMANCE_MONITORING" => 'true',
  "HTTP_MIQ_PERF_STACKPROF_RAW"      => 'true'
}

# Login
login_params = {
  :user_name     => "admin"
  :user_password => "smartvm"
}
app.post "/dashboard/authenticate", :params => login_params


# Requests to perform once logged in...


app.get "/dashboard/show", :headers => base_headers 

app.get "/catalog/explorer", :headers => base_headers 

# Token change expected, re-calculate csrf_token/base_headers/perf_headers
csrf_token        = app.response.body.match(CSRF_TOKEN_REGEXP)[:CSRF_TOKEN]
base_headers      = { "X-CSRF-Token" => csrf_token }
benchmark_headers = base_headers.merge(perf_headers)

app.post "/catalog/explorer?page=2&id=", :headers => base_headers 

app.post "/catalog/explorer?page=3&id=", :headers => base_headers 
```


### Options

#### `-a/--auto-profile`

Will automatically set `benchmark_headers` for requests that are considered
"slow" ("slow" is determined by `--threshold`).


#### `-t/--threshold`

Limit for normal requests that aren't considered "slow", in milliseconds.
Values above this amount will trigger the use of `benchmark_headers` when
`--auto-profile` is used.

Defaults to 10000.
