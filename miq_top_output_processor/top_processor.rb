#!/usr/bin/env ruby
require 'optparse'

options = { :worker_type => nil, :pid => nil, :pid_size => 5, :has_ppid => true, :offset => 0 }

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
  /top - (\d\d:\d\d:\d\d)\s*/,          # 1. Local Time
  /up\s*(\d* days?)?,?\s*/,             # 2. Uptime days
  /(\d?\d:\d\d|\d+ min),\s*/,           # 3. Uptime hours/min
  /(\d* users?),\s*/,                   # 4. Logged in users
  /load average:\s*/,
  /([\d\.]*),\s*/,                      # 5. Load 1 min
  /([\d\.]*),\s*/,                      # 6. Load 5 min
  /([\d\.]*)/                           # 7. Load 6 min
].map(&:source).join

# Parses a single line of the process info from the top output.
TOP_PROC_LINE_REGEXP = Regexp.new [
  /^([ 0-9]{#{options[:pid_size]}})\s/, # 1. PID
  /([ 0-9]{#{options[:ppid_size]}})/,   # 2. Parent PID (must be stripped)
  /(.{10})/,                            # 3. USER
  /(.{2})\s/,                           # 4. PR
  /(.{3})\s/,                           # 5. NICE Increment (I think?)
  /(.{7})\s/,                           # 6. Virtual Mem
  /(.{6})\s/,                           # 7. RSS
  /(.{6})\s/,                           # 8. SHR
  /(\w)\s/,                             # 9. S
  /(.{5})\s/,                           # 10. %CPU
  /(.{4})\s/,                           # 11. %MEM
  /(.{9})\s/,                           # 12. CPU TIME
  /(.*#{worker_type_regexp})$/          # 13. CMD
].map(&:source).join

# Pulls out the date from the timesync line in the top_output files.  Used to
# determine the current date.
TIMESYNC_REGEXP = /timesync: date time is-> (.*)$/

class DateStruct
  attr_reader :date

  class << self
    attr_accessor :tz_offset
  end

  def initialize(datetime_str)
    if datetime_str
      @datetime      = parse_time(datetime_str) - self.class.tz_offset

      @date          = @datetime.strftime("%Y-%m-%d")
      @date_1_hr_ago = (@datetime - 60*60).strftime("%Y-%m-%d")
      @date_add_1_hr = (@datetime + 60*60).strftime("%Y-%m-%d")
    end
  end

  # Checks the given timestamp to see if it should fall before, after, or on
  # the date in the struct
  #
  # timestamps given here should always be within 1 hour of the date when
  # initialized, so if it is not either hours 00 or 23, then we can just assume
  # it is the same date.
  def set_for_time timestamp
    return nil unless @date
    case timestamp[0,2]
    when "00"
      @datetime.hour == 23 ? @date_add_1_hr : @date
    when "23"
      @datetime.hour == 00 ? @date_1_hr_ago : @date
    else
      @date
    end
  end

  private

  # In ruby 2.2, there was a change to Time.parse where the current timezone of
  # the host computer was no longer interpreted when calling `Time.parse`.
  # These lines define methods so that the time parsing is consistent across
  # ruby versions, and uses the old implementation as the common denominator.
  if RbConfig::CONFIG["MAJOR"] == 2 && RbConfig::CONFIG["MAJOR"] > 1
    def parse_time(time); Time.parse(time).localtime; end
  else
    def parse_time(time); Time.parse(time); end
  end
end

DateStruct.tz_offset = options[:offset]

data_file   = {}
pid_buffer  = {}
date        = DateStruct.new(nil)

current_pid, time, cpu1, cpu5, cpu15 = nil


# Mem values from top are in KB
def to_bytes mem_val
  if mem_val.include? 'g'
    # Gigs to bytes
    (BigDecimal.new(mem_val) * 1000000000).to_i
  elsif mem_val.include? 'm'
    # MB to bytes
    (BigDecimal.new(mem_val) * 1000000).to_i
  else
    # kb to bytes
    mem_val.to_i * 1000
  end
end

require 'time'
require 'bigdecimal'

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
        # puts line
        time  = Regexp.last_match[1]
        cpu1  = Regexp.last_match[5]
        cpu5  = Regexp.last_match[6]
        cpu15 = Regexp.last_match[7]

      when TOP_PROC_LINE_REGEXP
        next if options[:pid] && Regexp.last_match[1].to_i != options[:pid]

        # Close the file since we have a new pid, and chances are the file will
        # not need to be re-opened.
        if data_file[current_pid] && current_pid != Regexp.last_match[1].to_i
          data_file[current_pid].close
        end

        current_pid = Regexp.last_match[1].to_i
        virt        = to_bytes(Regexp.last_match[6])
        res         = to_bytes(Regexp.last_match[7])
        shr         = to_bytes(Regexp.last_match[8])

        if data_file[current_pid] && data_file[current_pid].closed?
          data_file[current_pid].reopen(data_file[current_pid].path, "a")
        elsif current_pid and data_file[current_pid].nil? and not date.date.nil?
          datestamp = date.date.gsub(/[^0-9]/, '')
          filename  = "top_outputs/#{datestamp}_#{current_pid}.data"

          data_file[current_pid] = File.open(filename, :mode => "w")
        end

        pid_buffer[current_pid] ||= []
        pid_buffer[current_pid] << {
          :date => date.set_for_time(time),
          :time => time,
          :pid  => current_pid,
          :virt => virt,
          :res  => res,
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
        date = DateStruct.new Regexp.last_match[1]

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
