require 'optparse'

options = { :worker_type => nil, :pid => nil }

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] LOGFILE [LOGFILE] ..."

  opt.separator ""
  opt.separator "Parses the given log file and converts it into a gnuplot"
  opt.separator "format for turning metrics data into a graph."
  opt.separator ""
  opt.separator "Files can either be the raw log data, or their gzipped"
  opt.separator "equivalents, and the parser will figure out how to handle"
  opt.separator "them accordingly."
  opt.separator ""
  opt.separator "Options"

  opt.on("-pPID", "--pid=PID", Integer, "Specific PID to gather data for") do |pid|
    options[:pid] = pid.to_i
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

worker_type_regexp  = ".*"
worker_type_regexp += options[:worker_type] if options[:worker_type]

LOG_LINE_REGEXP = Regexp.new [
  /^\[----\] ([A-Z]), /,               # 1. severity char
  /\[([-0-9]*)/,                       # 2. date
  /T([0-9:]*)/,                        # 3. Ttime
  /\.([0-9]*) /,                       # 4. .ms
  /#([0-9]*)/,                         # 5. #pid
  /:([a-z0-9]*)\] +/,                  # 6. :thread
  /[A-Z]{0,5} -- [^:]*: /,
  /MIQ\(#{worker_type_regexp}\) .*/,
  /Memory Info XXXX /,
  /(\([^\)]*\) )?=> /,                 # 7. msg (queue msg, etc)
  /(\{[^\}]*\})/                       # 8. mem info
].map(&:source).join

DATE=2
TIME=3
PID=5
MSG=7
INFO=8

data_file   = nil
current_pid = nil

dir_names = log_files.map {|f| File.dirname(f) }.uniq
raise "ETOOMANYDIRS: gather all sources from a single dir, or pass -d" if dir_names.count > 1
dirname = dir_names.first
output_dir, dumps_dir = if dirname.include?("logs")
                          [dirname.sub("logs", "output"), dirname.sub("logs", "dumps")]
                        else
                          [File.join(dirname, "output"), File.join(dirname, "dumps")]
                        end

unless Dir.exists?(output_dir) && Dir.exists?(dumps_dir)
  require 'fileutils'

  FileUtils.mkdir_p [output_dir, dumps_dir]
end

log_files.each do |log_file|
  io_klass = if File.extname(log_file) == ".gz"
               require 'zlib'
               Zlib::GzipReader
             else
               File
             end

  io_klass.open(log_file) do |file|
    file.each_line do |line|
      next unless line_match = line.match(LOG_LINE_REGEXP)
      next if options[:pid] && options[:pid] != line_match[PID]

      # Close the file since we have a new pid and sets to nil
      data_file = data_file.close if data_file && current_pid != line_match[PID]

      date        = line_match[DATE]
      time        = line_match[TIME]
      current_pid = line_match[PID]
      msg         = line_match[MSG]
      info        = eval line_match[INFO]

      unless data_file
        datestamp = date.gsub(/[^0-9]/, '')
        filename  = File.join output_dir, "#{datestamp}_#{current_pid}.data"
        data_file = File.open(filename, :mode => "w")

        # TODO:  The code below assumes the timesstamps are in pacific, and the
        # current timezone is in central.  Needs to be made more universal.
        File.write File.join(output_dir, "#{datestamp}_#{current_pid}.impulses"),
                   Dir.glob(File.join dumps_dir, "*_#{current_pid}.dump.gz")
                      .map { |file| File.basename(file).split("_")[-2].to_i }
                      .map { |time| (Time.at(time).utc + -14400).strftime("%Y-%m-%dT%H:%M:%S 2000000000") }
                      .join("\n")
      end

      data_file.puts "#{date}T#{time} #{info[:PSS]} #{info[:RSS]} #{info[:Live]} #{info[:Old]}"
    end
  end
end
