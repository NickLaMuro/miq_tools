require "config/environment"
require "manageiq-gems-pending"
require "util/miq-process"
require "active_support/all"

proctitle = "Testing require 'linux_admin'"

Process.setproctitle proctitle

puts "PID: #{Process.pid}"
puts "Proctitle: #{proctitle}"
puts "Starting loop..."

loop do
  require 'linux_admin'

  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
