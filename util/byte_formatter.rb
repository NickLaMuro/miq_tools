class ByteFormatter
  # Mem values from top are in KB
  def self.to_bytes mem_val
    if mem_val.include? 'g'
      # Gigs to bytes
      (BigDecimal.new(mem_val) * 1_000_000_000).to_i
    elsif mem_val.include? 'm'
      # MB to bytes
      (BigDecimal.new(mem_val) * 1_000_000).to_i
    else
      # kb to bytes
      mem_val.to_i * 1000
    end
  end
end
