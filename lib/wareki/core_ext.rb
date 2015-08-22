require 'date'
require 'wareki/date'
module Wareki
  module CoreExt
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
end
