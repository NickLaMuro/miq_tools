# Put in /var/www/miq/vmdb on an appliance and run with the following:
#
#     sudo /bin/sh -c "source /etc/default/evm; ruby -I. 02_benchmark_realtime_block_loop_test.rb"
#
# To monitor, press ctrl-z, and take the pid and run with either
# smaps_monitor.rb or simple_memory_monitor.rb
#

puts "PID: #{Process.pid}"

require 'config/environment.rb'

puts "starting loop..."

def monitor
  # intentional no-op
end

loop do
  _dummy, timings = Benchmark.realtime_block(:total_time) { monitor }
  sleep 0.5
end
