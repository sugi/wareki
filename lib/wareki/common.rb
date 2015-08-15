# conding: utf-8
require 'wareki/calendar_def'
require 'wareki/era_def'
module Wareki
  GREGORIAN_START = 2405160 # Date.new(1873, 1, 1, Date::GREGORIAN).jd
  GREGORIAN_START_YEAR = 1873
  IMPERIAL_START = 1480041  # Date.new(-660, 2, 11, Date::GREGORIAN).jd
  IMPERIAL_START_YEAR = -660

  class UnsupportedDateRange < StandardError; end

  module Utils
    module_function
    def _to_date(d)
      if d.kind_of? ::Date
        d # nothing to do
      elsif d.kind_of?(Time)
        d.to_date
      else
        ::Date.jd(d.to_i)
      end
    end

    def _to_jd(d)
      if d.kind_of? ::Date
        d.jd
      elsif d.kind_of?(Time)
        d.to_date.jd
      else
        d.to_i
      end
    end

    def find_date_ary(d)
      d = _to_date(d).new_start(::Date::GREGORIAN)
      if d.jd >= GREGORIAN_START
        return [d.year, d.month, d.day, false]
      end

      yobj = find_year(d) or raise UnsupportedDateRange, "Unsupported date: #{d.inspect}"
      month = 0
      is_leap = false
      if yobj.month_starts.last <= d.jd
        month = yobj.month_starts.count
      else
        month = yobj.month_starts.find_index {|m| d.jd <= (m - 1) }
      end
      month_start = yobj.month_starts[month-1]
      is_leap = (yobj.leap_month == (month - 1))
      if yobj.leap_month && yobj.leap_month < month
        month -= 1
      end
      [yobj.year, month, d.jd - month_start +1, is_leap]
    end

    def find_year(d)
      d = _to_date(d)
      YEAR_DEFS.bsearch{|y| y.end > d.jd }
    end

    def find_era(d)
      jd = _to_jd(d)
      ERA_DEFS.bsearch{|e| e.end > jd }
    end
  end
end
