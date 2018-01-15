puts "PID: #{Process.pid}"

require 'config/environment.rb'

server   = MiqServer.my_server
settings = server.sync_worker_monitor_settings

puts "starting loop..."

do_gc = nil
loop do
  server.kill_workers_due_to_resources_exhausted?
  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 1
end
