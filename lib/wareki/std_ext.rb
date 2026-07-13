# frozen_string_literal: true

require 'date'
require 'wareki/date'
module Wareki
  # :nodoc:
  module StdExt
    module_function

    def wareki_directive?(format)
      !!(format.to_str =~ Wareki::Date::FORMAT_EXPANSION_REGEX)
    end
  end
end

# :nodoc:
class Date
  JAPAN = Wareki::GREGORIAN_START

  def to_wareki_date
    Wareki::Date.jd(jd)
  end

  alias _wareki_strftime_orig strftime
  def strftime(format = '%F')
    return _wareki_strftime_orig(format) unless Wareki::StdExt.wareki_directive?(format)

    _wareki_strftime_orig(to_wareki_date.expand_wareki_format(format))
  end

  class << self
    alias _wareki_parse_orig parse
    def parse(str = '-4712-01-01', comp = true, start = ::Date::ITALY)
      str = Wareki::Utils.normalize_time(str)
      str.to_s =~ Wareki::PARSE_QUICK_FILTER or
        return ::Date._wareki_parse_orig(str, comp, start)
      Wareki::Date.parse(str).to_date(start)
    rescue Wareki::InvalidDate
      raise
    rescue ArgumentError, Wareki::UnsupportedDateRange
      ::Date._wareki_parse_orig(str, comp, start)
    end

    alias _wareki__parse_orig _parse
    def _parse(str, comp = true)
      str = Wareki::Utils.normalize_time(str)
      str.to_s =~ Wareki::PARSE_QUICK_FILTER or
        return ::Date._wareki__parse_orig(str, comp)
      di = Wareki::Date._parse(str)
      wdate = Wareki::Date.new(di[:era], di[:year], di[:month], di[:day], di[:is_leap])
    rescue ArgumentError, Wareki::UnsupportedDateRange
      ::Date._wareki__parse_orig(str, comp)
    else
      ::Date._wareki__parse_orig(str.sub(Wareki::REGEX, wdate.strftime('%F ')), comp)
    end
  end
end

# :nodoc:
class DateTime
  alias _wareki_strftime_orig strftime
  def strftime(format = '%FT%T%:z')
    return _wareki_strftime_orig(format) unless Wareki::StdExt.wareki_directive?(format)

    _wareki_strftime_orig(to_wareki_date.expand_wareki_format(format))
  end
end
