puts "PID: #{Process.pid}"

require 'config/environment.rb'

# Preload all of the classes, so we can monkey patch them below
MiqServer.monitor_class_names.each do |class_name|
  class_name.constantize
end

# Monkey patch all of the worker types so that we only run the portions of it
# that don't manipulate the existing server process.
#
# skips/removes the `if current != desired` bit.
#
class MiqWorker < ApplicationRecord
  def self.sync_workers
    w       = include_stopping_workers_on_synchronize ? find_alive : find_current_or_starting
    current = w.length
    desired = self.has_required_role? ? workers : 0
    result  = {:adds => [], :deletes => []}
    result
  end
end

module PerEmsWorkerMixin
  module ClassMethods
    def sync_workers
      ws      = find_current_or_starting
      current = ws.collect(&:queue_name).sort
      desired = self.has_required_role? ? desired_queue_names.sort : []
      result  = {:adds => [], :deletes => []}
      result
    end
  end
end

module MiqWebServerWorkerMixin
  module ClassMethods
    def sync_workers
      # TODO: add an at_exit to remove all registered ports and gracefully stop apache
      self.registered_ports ||= []

      workers = find_current_or_starting
      current = workers.length
      desired = self.has_required_role? ? self.workers : 0
      result  = {:adds => [], :deletes => []}
      ports = all_ports_in_use

      # TODO: This tracking of adds/deletes of pids and ports is not DRY
      ports_hash = {:deletes => [], :adds => []}
      result
    end
  end
end

puts "starting loop..."

do_gc = nil
loop do
  MiqServer.monitor_class_names.each do |class_name|
    class_name.constantize.sync_workers
  end
  (GC.start; do_gc = false)   if do_gc  && Time.now.min % 2 == 0
  do_gc = true                if !do_gc && Time.now.min % 2 != 0
  sleep 0.5
end
