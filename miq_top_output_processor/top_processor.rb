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
    options[:pid] = pid.to_i
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

DateStringStruct.tz_offset = options[:offset]

data_file   = {}
pid_buffer  = {}
date        = DateStringStruct.new(nil)

current_pid, time, cpu1, cpu5, cpu15 = nil

Dir.mkdir "top_outputs" unless Dir.exists? "top_outputs"

log_files.each do |log_file|
  io_klass = if File.extname(log_file) == ".gz"
               require 'zlib'
               Zlib::GzipReader
             else
               File
             end

  io_klass.open(log_file) do |file|
    lineno = 0
    file.each_line do |line|
      lineno += 1

      case line
      when TOP_UPTIME_LINE_REGEXP
        time  = Regexp.last_match["LOCAL_TIME"]
        cpu1  = Regexp.last_match["LOAD_1"]
        cpu5  = Regexp.last_match["LOAD_5"]
        cpu15 = Regexp.last_match["LOAD_15"]

      when TOP_PROC_LINE_REGEXP
        next if options[:pid] && Regexp.last_match["PID"].to_i != options[:pid]

        # Close the file since we have a new pid, and chances are the file will
        # not need to be re-opened.
        if data_file[current_pid] && current_pid != Regexp.last_match["PID"].to_i
          data_file[current_pid].close
        end

        current_pid = Regexp.last_match["PID"].to_i
        virt        = ByteFormatter.to_bytes(Regexp.last_match["VIRT"])
        rss         = ByteFormatter.to_bytes(Regexp.last_match["RSS"])
        shr         = ByteFormatter.to_bytes(Regexp.last_match["SHR"])

        if data_file[current_pid] && data_file[current_pid].closed?
          data_file[current_pid].reopen(data_file[current_pid].path, "a")
        elsif current_pid and data_file[current_pid].nil? and not date.date.nil?
          datestamp = date.date.gsub(/[^0-9]/, '')
          filename  = "top_outputs/#{datestamp}_#{current_pid}.data"

          puts "creating new file:  #{filename}" if options[:verbose]
          data_file[current_pid] = File.open(filename, :mode => "w")
        end

        pid_buffer[current_pid] ||= []
        pid_buffer[current_pid] << {
          :date => date.set_for_time(time),
          :time => time,
          :pid  => current_pid,
          :virt => virt,
          :res  => rss,
          :shr  => shr,
        }
        next if data_file[current_pid].nil? || data_file[current_pid].closed?

        until pid_buffer[current_pid].empty?
          info = pid_buffer[current_pid].shift

          begin
            data_file[current_pid].puts "#{info[:date]}T#{info[:time]} #{info[:res]} #{info[:virt]} #{info[:shr]} #{lineno}"
          rescue => e
            puts data_file.inspect
            puts line
            raise e
          end
        end if pid_buffer[current_pid]

      when TIMESYNC_REGEXP
        date = DateStringStruct.new Regexp.last_match["DATE_STRING"]

        (pid_buffer[current_pid] || []).each do |entry|
          puts entry unless entry[:time]
          entry[:date] = date.set_for_time(entry[:time]) unless entry[:date]
        end
      end
    end
  end
end

data_file.each do |_, file|
  file.close unless file.closed?
end
