# Put in /var/www/miq/vmdb on an appliance and run with the following:
#
#     sudo /bin/sh -c "source /etc/default/evm; ruby -I. 05_miq_server_sync_needed_loop_test.rb"
#
# To monitor, press ctrl-z, and take the pid and run with either
# smaps_monitor.rb or simple_memory_monitor.rb
#

puts "PID: #{Process.pid}"

require 'config/environment.rb'

server   = MiqServer.my_server
settings = server.sync_worker_monitor_settings
settings[:sync_interval] = 1.minute

server.instance_variable_set(:@blacklisted_events, true)
server.instance_variable_set(:@config_last_loaded, ::Vmdb::Settings.last_loaded)
server.sync_active_roles

puts "starting loop..."
loop do
  server.sync_needed?
  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 1
end
