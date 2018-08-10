# Parses multiple files, gzip'd or not, and outputs the parsed data to 1 or
# many files
class MultiFileLogParser
  def self.parse log_files, options={}, match_regexps={}
    new(log_files, options, match_regexps).parse_files
  end

  def initialize log_files, options={}, match_regexps={}
    @log_files     = log_files
    @options       = options
    @match_regexps = match_regexps

    @id_col        = options[:id_col]
    @current_id    = nil
    @data_file     = {}
    @match_buffer  = {}
    # @id_buffer     = {}
  end

  def parse_files
    @log_files.each do |log_file|
      io_klass = determine_io_klass_for log_file
      io_klass.open(log_file) do |file|
        parse_file file
      end
    end
  end

  def parse_file file
    lineno = 0
    file.each_line do |line|
      lineno += 1

      @match_regexps.each do |regexp, block|
        next unless line_match = valid_line_for(line, regexp)

        set_match_buffer_for line_match
        update_current_file_and_current_id

        block.call(@current_id, @data_file, @match_buffer, lineno) if block
      end
    end
  end

  private

  def determine_io_klass_for file
    if File.extname(file) == ".gz"
      require 'zlib'
      Zlib::GzipReader
    else
      File
    end
  end

  # Determines if a given line is valid for the regexp
  #
  # The given line is valid if:
  #
  #   * it matches the regexp given
  #   * the following aren't true together
  #     - There is an @options[:id] (filtering limited by an ID field)
  #     - The regexp includes the id_col capture key
  #     - The @options[:id] does not equal the matched id_col in the regexp
  def valid_line_for line, regexp
    @has_id_col = nil
    @line_id    = nil
    return nil unless line_match = line.match(regexp)
    return nil if @options[:id] &&
                  has_id_col?(line_match) &&
                  @options[:id] != line_id(line_match)
    line_match
  end

  # Check to see if this match data has the @id_col in it's matches
  #
  # Note:  The optional `line_match` variable allows this method to be used as
  # a quick check on the instance variable, without trying to set it.  This is
  # used in MultiFileLogParser#update_current_file_and_current_id
  def has_id_col? line_match = nil
    # line_match && line_match.regexp.named_captures.keys.include?(@id_col)
    return nil if @has_id_col.nil? && line_match.nil?
    @has_id_col ||= line_match.regexp.named_captures[@id_col]
  end

  def line_id line_match = nil
    return nil if @line_id.nil? && line_match.nil?
    @line_id ||= line_match[@id_col].strip
  end

  # Set matches from the line_match to @match_buffer
  #
  # The match_buffer is there for keeping track of matches that happen from
  # certain regexp patterns that happen on a less frequent basis than others,
  # but that data is needed by the more frequent matches.
  def set_match_buffer_for line_match
    line_match.regexp.named_captures.each do |col, _|
      @match_buffer[col] = line_match[col]
    end
  end

  # Close currently opened file if current_id changed
  #
  # If a new "id" comes up in the match and we have an open file for that id,
  # close the existing file and update the @current_id
  #
  # From there, determine if we should create a new file, or open an existing
  # one, if needed.
  #
  # It is also possible for the currently opened file and id can also be remain
  # the same after this method has run.
  def update_current_file_and_current_id
    if @data_file[@current_id] && has_id_col? && @current_id != line_id
      @data_file[current_pid].close
    end

    @current_id = line_id

    if @data_file[@current_id] && @data_file[@current_id].closed?
      @data_file[@current_id].reopen(@data_file[@current_id].path, "a")
    elsif @current_id and @data_file[@current_id].nil? and not date.nil?
      set_datestamp
      # TODO:  Make this configurable ---v
      filename  = "#{@match_buffer["_datestamp"]}_#{@current_id}.data"
      filename  = File.join @options[:output_dir], filename

      puts "creating new file:  #{filename}" if @options[:verbose]
      @data_file[@current_id] = File.open(filename, :mode => "w")
    end
  end

  # Find the date based on the current match data
  def date
    @match_buffer["date"]
  end

  def set_datestamp
    @match_buffer["_datestamp"] = date.gsub(/[^0-9]/, '')
  end
end
