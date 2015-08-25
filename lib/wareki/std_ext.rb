require 'date'
require 'wareki/date'
module Wareki
  module StdExt
  end
end
class Date
  JAPAN = Wareki::GREGORIAN_START

  def to_wareki_date
    Wareki::Date.jd(self.jd)
  end

  alias_method :_wareki_strftime_orig, :strftime
  def strftime(format = "%F")
    if format.index("%J")
      to_wareki_date.strftime(format)
    else
      _wareki_strftime_orig(format)
    end
  end

  class << self
    alias_method :_wareki_parse_orig, :parse
    def parse(str, comp = true, start = ::Date::ITALY)
      begin
        Wareki::Date.parse(str).to_date(start)
      rescue => e
        ::Date._wareki_parse_orig(str, comp, start)
      end
    end
  end
end
