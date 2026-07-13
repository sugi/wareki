# frozen_string_literal: true

require 'ya_kansuji'

module Wareki
  # Static utility methods.
  module Utils
    TIME_FORMAT_DIRECTIVE_REGEX = /%J(-|[_0]{0,2}[0-9]*|)(T(?:[fF]|[HMS]k?))/.freeze
    TIME_FORMAT_EXPANSION_REGEX = /(?<!%)(?:%%)*\K#{TIME_FORMAT_DIRECTIVE_REGEX}/.freeze

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
      return era_year if ['', '西暦'].include?(era_name)
      return -era_year if era_name == '紀元前'
      return era_year + IMPERIAL_START_YEAR if IMPERIAL_ERA_NAMES.include?(era_name)

      era = ERA_BY_NAME[era_name] or
        raise ArgumentError, "Undefined era '#{era_name}'"
      era.year + era_year - 1
    end

    def civil_to_era_year(era_name, year)
      era_name = era_name.to_s
      return year if ['', '西暦'].include?(era_name)
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
      ERA_DEFS.reverse_each do |e|
        e.start > jd and next
        e.end < jd and next
        return e
      end
      nil
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

    # 日本語の時刻表記 (漢数字・全角数字の時分秒、午前/午後、半、正午) を
    # 等価な "HH:MM(:SS)" 表記へ置換する。値の範囲チェックは行わず、
    # 妥当性判断は Ruby 標準パーサに委ねる (二十五時 -> "25:00")。
    def normalize_time(str)
      str.to_s =~ TIME_PARSE_QUICK_FILTER or return str
      str.to_s.sub(TIME_REGEX) { _time_match_to_s(Regexp.last_match) }
    end

    def _time_match_to_s(match)
      return '12:00' if match[:noon]

      hour = k2i(match[:hour])
      hour += 12 if match[:ampm] == '午後' && hour < 12
      min = 0
      min = 30 if match[:half]
      min = k2i(match[:min]) if match[:min]
      return Kernel.format('%<hour>02d:%<min>02d', hour: hour, min: min) unless match[:sec]

      Kernel.format('%<hour>02d:%<min>02d:%<sec>02d', hour: hour, min: min, sec: k2i(match[:sec]))
    end

    def number_format(opt)
      case opt
      when '', '0', '_0' then '%02d'
      when '-'           then '%d'
      when /_\Z/         then '%2d'
      when /0?_/         then "%#{opt.sub(/0?_/, '')}d"
      when /_?0/         then "%#{opt.sub(/_?0/, '0')}d"
      else "%0#{opt}d"
      end
    end

    def expand_time_format(format_str, time)
      format_str.to_str.gsub(TIME_FORMAT_EXPANSION_REGEX) { _format_time_directive($2, $1, time) || $& }
    end

    def _format_time_directive(key, opt, time)
      case key.to_sym
      when :Tf
        nf = number_format(opt)
        Kernel.format("#{nf}時#{nf}分#{nf}秒", time.hour, time.min, time.sec)
      when :TF
        "#{YaKansuji.to_kan(time.hour, :simple)}時#{YaKansuji.to_kan(time.min, :simple)}分" \
        "#{YaKansuji.to_kan(time.sec, :simple)}秒"
      when :TH  then i2z(time.hour)
      when :THk then YaKansuji.to_kan(time.hour, :simple)
      when :TM  then i2z(time.min)
      when :TMk then YaKansuji.to_kan(time.min, :simple)
      when :TS  then i2z(time.sec)
      when :TSk then YaKansuji.to_kan(time.sec, :simple)
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
      YaKansuji.to_kan(*args)
    end
  end
end
