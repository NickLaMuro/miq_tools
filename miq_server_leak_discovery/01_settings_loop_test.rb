# Put in /var/www/miq/vmdb on an appliance and run with the following:
#
#     sudo /bin/sh -c "source /etc/default/evm; ruby -I. 01_settings_loop_test.rb"
#
# To monitor, press ctrl-z, and take the pid and run with either
# smaps_monitor.rb or simple_memory_monitor.rb
#

require 'config/environment.rb'

puts "starting loop..."
loop do
  ::Settings.server.monitor_poll.to_i_with_method
  sleep 0.5
end
