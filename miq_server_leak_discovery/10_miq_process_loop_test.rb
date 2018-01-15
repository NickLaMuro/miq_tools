require "config/environment" unless ENV["WITHOUT_MIQ_ENV"]
require "manageiq-gems-pending"
require "util/miq-process"
require "active_support/all"

pid        = ARGV[0].to_i
proctitle  = "Testing MiqProcess.processInfo(#{pid})"
proctitle += " without manageiq environment" if ENV["WITHOUT_MIQ_ENV"]

Process.setproctitle proctitle

PROCESS_INFO_FIELDS = %i(priority memory_usage percent_memory percent_cpu memory_size cpu_time proportional_set_size unique_set_size)


puts "PID: #{Process.pid}"
puts "Proctitle: #{proctitle}"
puts "Starting loop..."

do_gc = nil
loop do
  pinfo = MiqProcess.processInfo(pid)
  pinfo.slice!(*PROCESS_INFO_FIELDS)
  pinfo[:os_priority] = pinfo.delete(:priority)

  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
