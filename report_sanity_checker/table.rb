
# class to help print a table
# used in a few places, but this is for report sanity checker
# formatting turned out to be a bad idea - would be nice to remove

class Table
  def initialize
    # current max width for the column
    @sizes = []
    # block to format the column ( think no longer needed)
    @fmt = []
    # name of FORMATTING method to use (could probably directly use block)
    @alignments = []
    # false if we don't display this column
    @display = []
  end

  # configure a column to be hidden
  def hide(col) ; @display[col] = false ; end
  def format(col, value = nil, alignment = :left, &block)
    @fmt[col] = value ? FORMATTING[value] : block
    @alignments[col] = alignment
  end

  # configure padding for a column
  def pad(col, values)
    @sizes[col] =
      if values.kind_of?(Numeric)
        [@sizes[col] || 0, values].max
      else
        (values.map { |v| v.try(&:size) || 0 } << (@sizes[col] || 0)).max
      end
  end

  def print_hdr(*values)
    print "| "
    values.each_with_index do |value, col|
      print fmt(col, value, false), " | " if show?(col)
    end
    print "\n"
  end

  # TODO: add ":" to l/r pad
  def print_dash
    print "|"
    print *@sizes.each_with_index.map { |_, i| (align(i) == :left ? ":" : "-") + "-" * (sizes(i) || 3) + (align(i) == :right ? ":" : "-") + "|" if show?(i)}
    print "\n"
  end


  def print_col(*values)
    print "| "
    values.each_with_index do |value, col|
      print fmt(col, value), " | " if show?(col)
    end
    print "\n"
  end

  private
  # formatter for a string
  NUTTIN = -> (value, size) { value }
  RPAD = -> (value, size) { "%*s" % [size, value] }
  LPAD = -> (value, size) { "%-*s" % [size, value] }
  FORMATTING = { :right => RPAD, :left => LPAD }.freeze

  private

  def sizes(col) ; @sizes[col] ; end
  def fmt(col, val, do_format = true)
    sz = sizes(col)
    val = @fmt[col].call(val, sz) if (do_format && @fmt[col])
    (FORMATTING[@alignments[col]] || LPAD).call(val, sz)
  end
  def show?(col) ; @display[col] != false ; end
  def align(col) ; @alignments[col] || :left ; end

  def f_to_s(f, tgt = 1)
    if f.kind_of?(Numeric)
      parts = f.round(tgt).to_s.split('.')
      parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
      parts.join('.')
    else
      (f || "")
    end
  end

  def z_to_s(f, tgt = 1)
    f.kind_of?(Numeric) && f.round(tgt) == 0.0 ? nil : f_to_s(f, tgt)
  end
end
