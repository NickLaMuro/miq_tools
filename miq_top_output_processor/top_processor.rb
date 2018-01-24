#!/usr/bin/env ruby
require 'optparse'

options = {
  :offset => 0,
  :pid => nil,
  :has_ppid => true,
  :pid_size => 5,
  :worker_type => nil,
  :verbose => true
}

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] TOP_OUTPUT_FILE [TOP_OUTPUT_FILE] ..."

  opt.separator ""
  opt.separator "Parses the given log file and converts it into a gnuplot"
  opt.separator "format for turning metrics data into a graph."
  opt.separator ""
  opt.separator "Files can either be the raw log data, or their gzipped"
  opt.separator "equivalents, and the parser will figure out how to handle"
  opt.separator "them accordingly."
  opt.separator ""
  opt.separator "Options"

  opt.on("-o", "--offset=HRS", Integer, "Offset, in hours, from top to the host machine") do |offset|
    options[:offset] = offset.to_i
  end

  opt.on("-pPID", "--pid=PID", Integer, "Specific PID to gather data for") do |pid|
    options[:pid] = pid.to_s
  end

  opt.on("-P", "--[no-]ppid", [TrueClass, FalseClass], "Toggle if PPID field is present") do |has_ppid|
    options[:has_ppid] = has_ppid
  end

  opt.on(         "--pid-size=NUM", Integer, "Number of digits for PIDs in top (def: 5)") do |size|
    options[:pid_size] = size.to_i
  end

  opt.on("-wWORKER", "--worker-type=WORKER", String, "Worker type filter") do |type|
    options[:worker_type] = "#{type}.*"
  end

  opt.on("-v", "--[no-]verbose", [TrueClass, FalseClass], "Toggle extra debugging (def: true)") do |verbose|
    options[:verbose] = verbose
  end

  opt.on("-h",    "--help",                    "Show this message") do
    puts opt
    exit
  end
end.parse!


log_files = ARGV[0..-1]
raise "Please provide a file(s) to analyze" if log_files.empty?

# By default, we match all workers, but will match a specific worker if one is
# provided in the options.
worker_type_regexp  = ".*"
worker_type_regexp += options[:worker_type] if options[:worker_type]

# The +1 is to account for the space
options[:ppid_size] = options[:has_ppid] ? options[:pid_size] + 1 : 0

# Regexp for parsing the first line of the top output.  Mostly used to
# determine the current time the top sample was taken.
TOP_UPTIME_LINE_REGEXP = Regexp.new [
  /top - /,
  /(?<LOCAL_TIME>\d\d:\d\d:\d\d)\s*/,         # 1. Local Time
  /up\s*/,
  /(?<UPTIME_DAYS>\d* days?)?,?\s*/,          # 2. Uptime days
  /(?<UPTIME_HOURS>\d?\d:\d\d|\d+ min),\s*/,  # 3. Uptime hours/min
  /(?<LOGGED_IN_USERS>\d* users?),\s*/,       # 4. Logged in users
  /load average:\s*/,
  /(?<LOAD_1>[\d\.]*),\s*/,                   # 5. Load 1 min
  /(?<LOAD_5>[\d\.]*),\s*/,                   # 6. Load 5 min
  /(?<LOAD_15>[\d\.]*)/                       # 7. Load 15 min
].map(&:source).join

# Parses a single line of the process info from the top output.
TOP_PROC_LINE_REGEXP = Regexp.new [
  /(?<PID>[ 0-9]{#{options[:pid_size]}})\s/,  # 1. PID
  /(?<PPID>[ 0-9]{#{options[:ppid_size]}})/,  # 2. Parent PID (must be stripped)
  /(?<USER>.{10})/,                           # 3. USER
  /(?<PR>.{2})\s/,                            # 4. PR
  /(?<NI>.{3})\s/,                            # 5. NICE Increment (I think?)
  /(?<VIRT>.{7})\s/,                          # 6. Virtual Mem
  /(?<RSS>.{6})\s/,                           # 7. RSS
  /(?<SHR>.{6})\s/,                           # 8. SHR
  /(?<S>\w)\s/,                               # 9. S
  /(?<CPU%>.{5})\s/,                          # 10. %CPU
  /(?<MEM%>.{4})\s/,                          # 11. %MEM
  /(?<CPU_TIME>.{9})\s/,                      # 12. CPU TIME
  /(?<CMD>.*#{worker_type_regexp})$/          # 13. CMD
].map(&:source).unshift("^").join

# Pulls out the date from the timesync line in the top_output files.  Used to
# determine the current date.
TIMESYNC_REGEXP = /timesync: date time is-> (?<DATE_STRING>.*)$/

$: << File.expand_path(File.join("..", "..", "util"), __FILE__)
require 'byte_formatter'
require 'time'
require 'bigdecimal'
require 'date_string_struct'
require 'multi_file_log_parser'

DateStringStruct.tz_offset = options[:offset]

data_file   = {}
pid_buffer  = {}
date_struct  = DateStringStruct.new(nil)

Dir.mkdir "top_outputs" unless Dir.exists? "top_outputs"

parser_options = {
  :id         => options[:pid],
  :id_col     => "PID",
  :output_dir => "top_outputs",
  :verbose    => options[:verbose]
}

line_matchers  = {
  TOP_UPTIME_LINE_REGEXP => nil,
  TOP_PROC_LINE_REGEXP   => ->(pid, data_file, match_buffer, lineno) {
    pid_buffer[pid] ||= []
    pid_buffer[pid] << {
      :date => date_struct.set_for_time(match_buffer["LOCAL_TIME"]),
      :time => match_buffer["LOCAL_TIME"],
      :pid  => pid,
      :virt => ByteFormatter.to_bytes(match_buffer["VIRT"]),
      :res  => ByteFormatter.to_bytes(match_buffer["RSS"]),
      :shr  => ByteFormatter.to_bytes(match_buffer["SHR"]),
    }
    next if data_file[pid].nil? || data_file[pid].closed?

    until pid_buffer[pid].empty?
      info = pid_buffer[pid].shift

      data_file[pid].puts "#{info[:date]}T#{info[:time]} " \
                          "#{info[:res]} #{info[:virt]} "  \
                          "#{info[:shr]} #{lineno}"
    end if pid_buffer[pid]
  },
  TIMESYNC_REGEXP        => ->(pid, data_file, match_buffer, _) {
    date_struct = DateStringStruct.new match_buffer["DATE_STRING"]
    match_buffer["date"] = date_struct.date

    pid_buffer.each do |_, buffer|
      (buffer || []).each do |entry|
        puts entry unless entry[:time] #debug
        entry[:date] = date_struct.set_for_time(entry[:time]) unless entry[:date]
      end
    end
  }
}

MultiFileLogParser.parse log_files, parser_options, line_matchers
