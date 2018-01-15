puts "PID: #{Process.pid}"

require 'config/environment.rb'
require 'drb'
require 'drb/acl'

# Server object and DRb::DRbServer setup
server = MiqServer.my_server
server.setup_drb_variables

acl = ACL.new(%w(deny all allow 127.0.0.1/32))
DRb.install_acl(acl)

drb_server = DRb.start_service("druby://127.0.0.1:0", server)

worker_pids = []


# Worker heartbeat loops
5.times do
  pid = fork do
    MiqWorker.after_fork

    require 'drb'
    drb = DRbObject.new(nil, drb_server.uri)
    pid = Process.pid

    loop do
      msgs = drb.worker_heartbeat(pid)
      msgs.each do |msg|
        msg.reverse #work
      end
      sleep 1
    end
  end
  worker_pids << pid
  Process.detach(pid)
end

# Server monitor loop
puts "starting loop..."

do_gc = nil
loop do
  worker_pids.each do |pid|
    (rand(5) + 1).times { server.worker_add_message pid, "foo" }
  end

  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 1
end

DRb.thread.join
