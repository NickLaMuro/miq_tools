require "config/environment"
require "manageiq-gems-pending"
require "util/miq-process"
require "active_support/all"

pid       = ARGV[0].to_i
proctitle = "Testing MiqProcess.linux_process_stat(#{pid})"

Process.setproctitle proctitle

puts "PID: #{Process.pid}"
puts "Proctitle: #{proctitle}"
puts "Starting loop..."

loop do
  MiqProcess.linux_process_stat pid

  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
