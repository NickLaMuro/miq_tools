# Put in /var/www/miq/vmdb on an appliance and run with the following:
#
#     sudo /bin/sh -c "source /etc/default/evm; ruby -I. 03_heartbeat_loop_test.rb"
#
# To monitor, press ctrl-z, and take the pid and run with either
# smaps_monitor.rb or simple_memory_monitor.rb
#

puts "PID: #{Process.pid}"

require 'config/environment.rb'
server = MiqServer.my_server

puts "starting loop..."
loop do
  server.heartbeat
  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
