require 'sys-proctable'

loop do
  puts Sys::ProcTable.ps(ARGV[0].to_i).rss
  sleep 5
end
