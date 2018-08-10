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
    # just want to use the Integer to validate the number, but it is easier to
    # compare this as a string when parsing.
    options[:pid] = pid.to_s
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
  /(?<SEVERITY_CHAR>[A-Z]), \[/,       # 1. severity char
  /(?<date>[-0-9]*)T/,                 # 2. date
  /(?<TIME>[0-9:]*\.)/,                # 3. Ttime
  /(?<MS>[0-9]*) #/,                   # 4. .ms
  /(?<PID>[0-9]*):/,                   # 5. #pid
  /(?<THREAD>[a-z0-9]*)\] +/,          # 6. :thread
  /[A-Z]{0,5} -- [^:]*: /,
  /MIQ\(#{worker_type_regexp}\) .*/,
  /Memory Info XXXX /,
  /(?<MSG>\([^\)]*\) )?=> /,           # 7. msg (queue msg, etc)
  /(?<MEM_INFO>\{[^\}]*\})/            # 8. mem info
].map(&:source).unshift(/^\[----\] /.source).join

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

$: << File.expand_path(File.join("..", "..", "util"), __FILE__)
require 'multi_file_log_parser'

parser_options = {
  :id         => options[:pid],
  :id_col     => "PID",
  :output_dir => output_dir
}

impulse_data   = {}
line_matchers  = {
  LOG_LINE_REGEXP => ->(pid, data_file, line_match, _) {
    if impulse_data[pid].nil?
      impulse_data[pid] = true
      datestamp         = line_match["_datestamp"]

      # TODO:  The code below assumes the timesstamps are in pacific, and the
      # current timezone is in central.  Needs to be made more universal.
      File.write File.join(output_dir, "#{datestamp}_#{pid}.impulses"),
                 Dir.glob(File.join dumps_dir, "*_#{pid}.dump.gz")
                    .map { |file| File.basename(file).split("_")[-2].to_i }
                    .map { |time| (Time.at(time).utc + -14400).strftime("%Y-%m-%dT%H:%M:%S 2000000000") }
                    .join("\n")
    end

    info = eval line_match["MEM_INFO"]
    data_file[pid].puts "#{line_match["date"]}T#{line_match["TIME"]} " \
                        "#{info[:PSS]} #{info[:RSS]} "                 \
                        "#{info[:Live]} #{info[:Old]}"
  }
}

MultiFileLogParser.parse log_files, parser_options, line_matchers
