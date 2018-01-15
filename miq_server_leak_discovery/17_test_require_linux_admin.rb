require "config/environment" unless ENV["WITHOUT_MIQ_ENV"]
require "manageiq-gems-pending"
require "util/miq-process"
require "active_support/all"

proctitle  = "Testing require 'linux_admin'"
proctitle += " without manageiq environment" if ENV["WITHOUT_MIQ_ENV"]

gem_to_require = ENV["GEM_TO_REQUIRE"] || "linux_admin"

Process.setproctitle proctitle

puts "PID: #{Process.pid}"
puts "Proctitle: #{proctitle}"
puts "Starting loop..."

do_gc = nil
loop do
  require gem_to_require

  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
