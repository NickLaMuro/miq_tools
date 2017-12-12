# Put in /var/www/miq/vmdb on an appliance and run with the following:
#
#     sudo /bin/sh -c "source /etc/default/evm; ruby -I. 04_yaml_dump_loop_test.rb"
#
# To monitor, press ctrl-z, and take the pid and run with either
# smaps_monitor.rb or simple_memory_monitor.rb
#

puts "PID: #{Process.pid}"

require 'config/environment.rb'
require 'yaml'

hash = MiqServer.my_server.sync_worker_monitor_settings

puts "starting loop..."
loop do
  YAML.dump(hash.to_hash)
  sleep 1
end
