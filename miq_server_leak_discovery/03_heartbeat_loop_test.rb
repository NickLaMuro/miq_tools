ENV["BUNDLE_WITHOUT"] = "test:metric_fu:development"
ENV["BUNDLE_GEMFILE"] = "/var/www/miq/vmdb/Gemfile"
ENV["PATH"]           = "#{ENV['PATH']}:/opt/rubies/ruby-2.3.1/bin"

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
