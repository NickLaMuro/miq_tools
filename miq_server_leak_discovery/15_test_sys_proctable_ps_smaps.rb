require "config/environment" unless ENV["WITHOUT_MIQ_ENV"]
require "manageiq-gems-pending"
require "util/miq-process"
require "active_support/all"

pid        = ARGV[0].to_i
proctitle  = "Testing Sys::ProcTable.ps(#{pid}).smaps"
proctitle += " without manageiq environment" if ENV["WITHOUT_MIQ_ENV"]

Process.setproctitle proctitle

puts "PID: #{Process.pid}"
puts "Proctitle: #{proctitle}"
puts "Starting loop..."

loop do
  Sys::ProcTable.ps(pid).smaps

  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
