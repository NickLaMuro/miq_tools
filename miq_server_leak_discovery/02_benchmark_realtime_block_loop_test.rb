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
