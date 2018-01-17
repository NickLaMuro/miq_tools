require 'pathname'

puts Process.pid

paths = [
  Pathname.new("miq_server_leak_discovery"),
  Pathname.new("memory_dump_analyzer"),
  Pathname.new("benchmark_scripts"),
  Pathname.new("miq_top_output_processor")
]

paths.each { |path| $LOAD_PATH.unshift(path) }


dot      = "."
filename = "empty"

1500.times { 1500.times { require filename }; print dot; GC.start; }
