# Used for finding the date from an infrequently printed "timesync" timestamp
# (formatted: "%a %b %d %H:%M:%S %Z %Y %z") and a time only string (HH:MM:SS).
#
# Example:
#
#     > dss = DateStringStruct.new("Sun Jan 01 00:01:00 EST 2000 -0500")
#     > dss.set_for_time "00:00:00"
#     #=> "2000-01-01T00:00:00"
#     > dss.set_for_time "23:02:00"
#     #=> "1999-12-31T23:02:00"
#
class DateStringStruct
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
