require 'optparse'

options = { :generation => nil, :depth => 0 }

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] DUMPFILE"

  opt.separator ""
  opt.separator "Parses the given DUMPFILE (output from ObjectSpace.dump_all)"
  opt.separator "and either gives the generation statisics or the specific"
  opt.separator "memory locations of the objects in a given generation."
  opt.separator ""
  opt.separator "Files can either be the raw json data, or their gzipped"
  opt.separator "equivalents, and the parser will figure out how to handle"
  opt.separator "them accordingly."
  opt.separator ""
  opt.separator "Options"

  opt.on("-dDEPTH", "--depth=DEPTH",  Integer, "Level of referenced objects to view") do |val|
    options[:depth] = val
  end

  opt.on("-gNUM", "--generation=NUM", Integer, "Generation number to analyze") do |val|
    options[:generation] = val
  end

  opt.on("-i", "--[no-]interactive",           "View the dump in a irb session") do |val|
    options[:interactive] = val
  end

  opt.on("-h", "--help", "Show this message") { puts opt; exit }
end.parse!

require 'json'
require 'zlib'
require 'irb'

module IRB
  def self.start_session(binding)
    STDOUT.sync = true
    $0 = File::basename(__FILE__, ".rb")

    IRB.setup(__FILE__)

    workspace = WorkSpace.new(binding)
    if @CONF[:SCRIPT]
      irb = Irb.new(workspace, @CONF[:SCRIPT])
    else
      irb = Irb.new(workspace)
    end
    irb.run(@CONF)
  end
end

class IOReader
  attr_reader :filename, :depth

  def initialize filename, options = {}
    @filename = filename
    @depth    = options[:depth] || 1
    @data     = {}
  end

  def io_klass
    File.extname(@filename) == ".gz" ? Zlib::GzipReader : File
  end

  def read_lines
    io_klass.open(filename) do |f|
      f.each_line do |line|
        yield line
      end
    end
  end
end

class DumpHash < IOReader
  def initialize filename, options = {}
    super
    gather
  end

  def linked_objects objekt, current_depth = "  "
    objekt["references"].each do |obj_ref|
      nested_obj = @data[obj_ref]
      puts "#{current_depth}#{nested_obj["type"]} => #{nested_obj["file"]}:#{nested_obj["line"]}"
      linked_objects nested_obj, "#{current_depth}  " if current_depth.length / 2 < depth
    end if objekt["references"]
  end

  def interactive local_binding, options = {}
    local_binding.local_variable_set :dump, @data

    options[:locals].each do |var, val|
      local_binding.local_variable_set var, val
    end if options[:locals]

    IRB.start_session local_binding
  end

  private

  def gather
    read_lines do |line|
      line_data = JSON.parse line #, :symbolize_names => true
      @data[line_data["address"]] = line_data if line_data["address"]
    end
  end
end

class Analyzer < IOReader
  def initialize filename, options = {}
    super
    @generation = options[:generation]
    @data       = []
  end

  def analyze
    read_lines do |line|
      parsed = JSON.parse line #, :symbolize_names => true
      @data << parsed if @generation.nil? || parsed["generation"] == @generation
    end

    @generation ? print_for_speicific_generation : print_generation_count
  end

  private

  def print_generation_count
    @data.group_by { |row| row["generation"] }
         .sort     { |a,b| a[0].to_i <=> b[0].to_i }
         .each     { |k,v| puts "generation #{k} objects #{v.count}" }
  end

  def print_for_speicific_generation
    puts "Generation #{@generation}:\n"

    dump_hash = DumpHash.new filename, :depth => depth if depth > 0

    @data.group_by { |row| "#{row["file"]}:#{row["line"]}" }
         .sort     { |a,b| b[1].count <=> a[1].count }
         .each do |k,v|
           puts "#{v[0]["type"]} => #{k} * #{v.count}"
           if dump_hash
             v.each do |obj|
               puts ">>#{obj["address"]}"
               dump_hash.linked_objects obj
             end
           end
         end
  end
end


if options[:interactive]
  # Need to clear out ARGV, otherwise it mucks with IRB
  dump_file = ARGV.shift
  ARGV.clear
  DumpHash.new(dump_file, options).interactive(TOPLEVEL_BINDING.dup)
else
  Analyzer.new(ARGV[0], options).analyze
end
