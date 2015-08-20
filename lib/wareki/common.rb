# coding: utf-8
require 'wareki/calendar_def'
require 'wareki/era_def'
require 'date'
module Wareki
  GREGORIAN_START = 2405160 # Date.new(1873, 1, 1, Date::GREGORIAN).jd
  GREGORIAN_START_YEAR = 1873
  IMPERIAL_START = 1480041  # Date.new(-660, 2, 11, Date::GREGORIAN).jd
  IMPERIAL_START_YEAR = -660
  DATE_INFINITY = ::Date.new(2**(0.size * 8 -2) -1, 12, 31) # Use max Fixnum as year.
  YEAR_BY_NUM = Hash[*YEAR_DEFS.map{|y| [y.year, y]}.flatten].freeze
  ERA_BY_NAME = Hash[*(ERA_NORTH_DEFS + ERA_DEFS).map {|g| [g.name, g]}.flatten]
  ERA_BY_NAME['皇紀'] = ERA_BY_NAME['神武天皇即位紀元'] = Era.new('皇紀', -660, 1480041, DATE_INFINITY.jd)
  ERA_BY_NAME.freeze
  NUM_CHARS = "零〇一二三四五六七八九十卄廿卅丗卌肆百皕千万億兆0123456789０１２３４５６７８９"
  ALT_MONTH_NAME = %w(睦月 如月 弥生 卯月 皐月 水無月 文月 葉月 長月 神無月 霜月 師走).freeze
  REGEX = %r{
    (?<era_name>西暦|#{ERA_BY_NAME.keys.join('|')})?
    (?:(?<year>[元#{NUM_CHARS}]+)年)?
    (?:(?<is_leap>閏|潤|うるう)?
      (?:(?<month>[#{NUM_CHARS}]+)月 |
         (?<alt_month>#{ALT_MONTH_NAME.join('|')})))?
    (?:(?<day>[元朔晦#{NUM_CHARS}]+)日)?
  }x

  class UnsupportedDateRange < StandardError; end

  module Utils
    module_function
    def kan_to_i(str)
      ret = 0
      curnum = nil
      str == "零" and return 0
      str.to_s.each_char do |c|
        case c
        when *%w(元 朔 一 二 三 四 五 六 七 八 九 肆 1 2 3 4 5 6 7 8 9 １ ２ ３ ４ ５ ６ ７ ８ ９)
          if curnum
            curnum *= 10
          else
            curnum = 0
          end
          curnum += c.tr("一二三四五六七八九１２３４５６７８９肆元朔", "123456789123456789411").to_i
        when "〇", "０", "0"
          curnum and curnum *= 10
        when "卄", "廿"
          ret += 20
          curnum = nil
        when "卅", "丗"
          ret += 30
          curnum = nil
        when "卌"
          ret += 40
          curnum = nil
        when "皕"
          ret += 200
          curnum = nil
        when "十", "百", "千", "万", "億", "兆"
          if curnum
            ret += curnum * 10 ** (["十", "百", "千", "万", "億", "兆"].index(c)+1)
          else
            ret += 10 ** (["十", "百", "千", "万", "億", "兆"].index(c)+1)
          end
          curnum = nil
        end
      end
      if curnum
        ret += curnum
        curnum = nil
      end
      ret
    end

    def i_to_kan(num)
    end

    def alt_month_name_to_i(name)
      ALT_MONTH_NAME.index(name) + 1
    end

    def alt_month_name(month)
      ALT_MONTH_NAME[month - 1]
    end

    def parse(str, start = ::Date::ITALY)
      begin
        Date.parse(str).to_date(start)
      rescue ArgumentError => e
        ::Date.parse(str)
      end
    end

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
      jd = _to_jd(d)
      YEAR_DEFS.bsearch{|y| y.end > jd }
    end

    def find_era(d)
      jd = _to_jd(d)
      e = ERA_DEFS.bsearch{|e| e.end > jd }
      e.start > jd and return nil
      e
    end
  end
end
