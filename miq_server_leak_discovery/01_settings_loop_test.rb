require 'config/environment.rb'

puts "starting loop..."
loop do
  ::Settings.server.monitor_poll.to_i_with_method
  sleep 0.5
end
