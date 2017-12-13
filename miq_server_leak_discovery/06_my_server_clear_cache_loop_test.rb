puts "PID: #{Process.pid}"

require 'config/environment.rb'

server   = MiqServer.my_server

puts "starting loop..."
loop do
  server.class.my_server_clear_cache
  MiqServer.my_server
  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 1
end
