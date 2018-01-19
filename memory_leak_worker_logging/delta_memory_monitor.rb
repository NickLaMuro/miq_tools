require 'sys-proctable'

# comas at thousands marker
def delimit(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

old_memory = nil     # previous value of memory
old_memory_count = 1 # number of times this has been the same value
value = nil          # value to display

loop do
  puts Sys::ProcTable.ps(ARGV[0].to_i).rss
  new_memory = Sys::ProcTable.ps(ARGV[0].to_i).rss
  if old_memory != new_memory
    value = "#{delimit(new_memory)}#{old_memory ? " (𝛥#{delimit(new_memory - old_memory)})" : ""}"

    old_memory_count = 1
    old_memory = new_memory

    print "\n#{value}"
  else
    old_memory_count +=1
    print "\r#{value} x#{old_memory_count}"
  end
  sleep 5
end
