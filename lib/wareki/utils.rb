# frozen_string_literal: true

require 'ya_kansuji'

module Wareki
  # Static utility methods.
  module Utils
    module_function

    def last_day_of_month(year, month, is_leap)
      if year >= GREGORIAN_START_YEAR
        _last_day_of_month_gregorian(year, month)
      else
        _last_day_of_month_from_defs(year, month, is_leap)
      end
    end

    def _last_day_of_month_gregorian(year, month)
      ::Date.new(year, month, -1, ::Date::GREGORIAN).day
    end

    def _last_day_of_month_from_defs(year, month, is_leap)
      yobj = YEAR_BY_NUM[year] or
        raise UnsupportedDateRange, "Cannot find year #{year}"
      month_idx = month - 1
      month_idx += 1 if is_leap || (yobj.leap_month && yobj.leap_month < month)
      yobj.month_days[month_idx]
    end

    def era_year_to_civil(era_name, era_year)
      era_name = era_name.to_s
      return era_year if era_name == '' || era_name == '西暦'
      return -era_year if era_name == '紀元前'
      return era_year + IMPERIAL_START_YEAR if IMPERIAL_ERA_NAMES.include?(era_name)

      era = ERA_BY_NAME[era_name] or
        raise ArgumentError, "Undefined era '#{era_name}'"
      era.year + era_year - 1
    end

    def civil_to_era_year(era_name, year)
      era_name = era_name.to_s
      return year if era_name == '' || era_name == '西暦'
      return -year if era_name == '紀元前'
      return year - IMPERIAL_START_YEAR if IMPERIAL_ERA_NAMES.include?(era_name)

      era = ERA_BY_NAME[era_name] or
        raise ArgumentError, "Undefined era '#{era_name}'"
      year - era.year + 1
    end

    def last_day_of_era_month(era_name, civil_year, month, is_leap)
      if WESTERN_ERA_NAMES.include?(era_name.to_s)
        ::Date.new(civil_year, month, -1, ::Date::ITALY).day
      else
        last_day_of_month(civil_year, month, is_leap)
      end
    end

    def alt_month_name_to_i(name)
      i = ALT_MONTH_NAME.index(name) or return false
      i + 1
    end

    def alt_month_name(month)
      ALT_MONTH_NAME[month - 1]
    end

    def _to_date(d)
      if d.is_a? ::Date
        d # nothing to do
      elsif d.is_a?(Time)
        d.to_date
      else
        ::Date.jd(d.to_i)
      end
    end

    def _to_jd(d)
      if d.is_a? ::Date
        d.jd
      elsif d.is_a?(Time)
        d.to_date.jd
      else
        d.to_i
      end
    end

    def find_date_ary(d)
      d = _to_date(d).new_start(::Date::GREGORIAN)
      d.jd >= GREGORIAN_START and
        return [d.year, d.month, d.day, false]

      yobj = find_year(d) or raise UnsupportedDateRange, "Unsupported date: #{d.inspect}"
      month = 0
      if yobj.month_starts.last <= d.jd
        month = yobj.month_starts.count
      else
        month = yobj.month_starts.find_index { |m| d.jd <= (m - 1) }
      end
      month_start = yobj.month_starts[month - 1]
      is_leap = (yobj.leap_month == (month - 1))
      yobj.leap_month && yobj.leap_month < month and
        month -= 1
      [yobj.year, month, d.jd - month_start + 1, is_leap]
    end

    def find_year(d)
      jd = _to_jd(d)
      jd < YEAR_DEFS.first.start and return nil
      YEAR_DEFS.bsearch { |y| y.end >= jd }
    end

    def find_era(d)
      jd = _to_jd(d)
      era = ERA_JD_LOOKUP.bsearch { |e| e.end >= jd }
      era && era.start <= jd ? era : nil
    end

    def i2z(num)
      num.to_s.tr('0123456789', '０１２３４５６７８９')
    end

    def k2i(str)
      str = str.to_s.strip
      if %w(正 元 朔).member? str
        1
      else
        YaKansuji.to_i str
      end
    end

    # DEPRECATED
    def kan_to_i(*args)
      warn '[DEPRECATED] Wareki::Utils.kan_to_i: Please use ya_kansuji gem to handle kansuji'
      k2i(*args)
    end

    # DEPRECATED
    def i_to_kan(*args)
      warn '[DEPRECATED] Wareki::Utils.i_to_kan: Please use ya_kansuji gem to handle kansuji'
      i2k(*args)
    end
  end
end
