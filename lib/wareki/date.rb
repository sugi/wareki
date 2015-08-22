# coding: utf-8
require 'wareki/common'
require 'wareki/utils'
module Wareki

  class Date
    attr_reader :jd
    attr_accessor :year, :month, :day, :era_year, :era_name

    def self.parse(str)
      match = REGEX.match(str.to_s.gsub(/[[:space:]]/, ''))
      if !match || !match[:year]
        raise ArgumentError, "Invaild Date: #{str}"
      end
      era = match[:era_name]
      year = Utils.kan_to_i(match[:year])
      month = 1
      day = 1

      if era.to_s != "" && !ERA_BY_NAME[era]
        raise ArgumentError, "Date parse failed: Invalid era name '#{match[:era_name]}'"
      end

      if match[:month]
        month = Utils.kan_to_i(match[:month])
      elsif match[:alt_month]
        month = Utils.alt_month_name_to_i(match[:alt_month])
      end

      if match[:day]
        if match[:day] == "晦"
          day = Utils.last_day_of_month(ERA_BY_NAME[era].year + year -1, month, match[:is_leap])
        else
          day = Utils.kan_to_i(match[:day])
        end
      end

      if (era == "明治" && year == 5 ||
          era.to_s == "" && year == 1872 ||
          era == "皇紀" && year == 2532) &&
          month == 12 && day > 2
        raise ArgumentError, "Invaild Date: #{str}"
      end

      new(era, year, month, day, !!match[:is_leap])
    end

    def self.jd(d)
      era = Utils.find_era(d)
      era or raise UnsupportedDateRange, "Cannot find era for date #{d.inspect}"
      year, month, day, is_leap = Utils.find_date_ary(d)
      obj = new(era.name, year - era.year + 1, month, day, is_leap)
      obj.__set_jd(d)
      obj
    end

    def self.date(date)
      jd(date.jd)
    end

    def self.imperial(year, month = 1, day = 1, is_leap_month = false)
      new("皇紀", year, month, day, is_leap_month)
    end

    def initialize(era_name, era_year, month = 1, day = 1, is_leap_month = false)
      if era_name.to_s != "" && era_name != "西暦" && !ERA_BY_NAME[era_name]
        raise ArgumentError, "Undefined era '#{era_name}'"
      end
      @month = month
      @day = day
      @is_leap_month = is_leap_month
      @era_name = era_name
      @era_year = era_year
      if era_name.to_s == ""
        @year = @era_year
      elsif era_name == "皇紀" || era_name == "神武天皇即位紀元"
        @year = era_year + IMPERIAL_START_YEAR
      else
        @year = ERA_BY_NAME[era_name].year + era_year - 1
      end
    end

    def imperial_year
      @year - IMPERIAL_START_YEAR
    end

    def imperial_year=(v)
      @year = v - IMPERIAL_START_YEAR
    end

    def leap_month?
      !!@is_leap_month
    end

    def leap_month=(v)
      @is_leap_month = v
    end

    def __set_jd(v)
      @jd = v
    end

    def month_index
      if @era_name == "西暦" || @year >= GREGORIAN_START_YEAR
        return month -1
      end

      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot get year info of #{self.inspect}"
      idx = month - 1
      if leap_month? || yobj.leap_month && month > yobj.leap_month
        idx += 1
      end
      idx
    end

    def jd
      @jd and return @jd

      if @era_name == "西暦"
        return @jd = ::Date.new(@year, month, day, ::Date::ITALY).jd
      elsif @year >= GREGORIAN_START_YEAR
        return @jd = ::Date.new(@year, month, day, ::Date::GREGORIAN).jd
      end

      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot convert to jd #{self.inspect}"
      @jd = yobj.month_starts[month_index] + day - 1
    end

    def to_date(start = ::Date::ITALY)
      ::Date.jd(jd, start)
    end

    def strftime(format = "%JF")
      fmt_pat = {
        e: era_name,
        g: era_name.to_s == "" ? '' : era_year,
        G: era_name.to_s == "" ? '' : era_year.to_s.tr('0123456789', '０１２３４５６７８９'),
        Gk: era_name.to_s == "" ? '' : Utils.i_to_kan(era_year),
        GK: era_name.to_s == "" ? '' : Utils.i_to_kan(era_year),
        o: year,
        O: year.to_s.tr('0123456789', '０１２３４５６７８９'),
        Ok: Utils.i_to_kan(year),
        i: imperial_year,
        I: imperial_year.to_s.tr('0123456789', '０１２３４５６７８９'),
        Ik: Utils.i_to_kan(imperial_year),
        s: month,
        S: month.to_s.tr('0123456789', '０１２３４５６７８９'),
        Sk: Utils.i_to_kan(month),
        SK: ALT_MONTH_NAME[month-1],
        l: leap_month? ? "'" : "",
        L: leap_month? ? "’" : "",
        Lk: leap_month? ? "閏" : "",
        d: day,
        D: day.to_s.tr('0123456789', '０１２３４５６７８９'),
        Dk: Utils.i_to_kan(day),
        DK: Utils.i_to_kan(day),
      }
      era_year == 1 and
        fmt_pat[:GK] = "元"
      if month == 1 && !leap_month? && day == 1
        fmt_pat[:DK] = "元"
      elsif day == 1
        fmt_pat[:DK] = "朔"
      elsif day == Utils.last_day_of_month(year, month, leap_month?)
        fmt_pat[:DK] = "晦"
      end

      fmt_pat.update({
        m: "#{fmt_pat[:s]}#{fmt_pat[:l]}",
        M: "#{fmt_pat[:Lk]}#{fmt_pat[:S]}",
        Mk: "#{fmt_pat[:Lk]}#{fmt_pat[:Sk]}",
        y: "#{fmt_pat[:e]}#{fmt_pat[:g]}",
        Y: "#{fmt_pat[:e]}#{fmt_pat[:G]}",
        Yk: "#{fmt_pat[:e]}#{fmt_pat[:Gk]}",
        YK: "#{fmt_pat[:e]}#{fmt_pat[:GK]}",
        f: "#{fmt_pat[:e]}#{fmt_pat[:g]}年#{fmt_pat[:s]}#{fmt_pat[:l]}月#{fmt_pat[:d]}日",
        F: "#{fmt_pat[:e]}#{fmt_pat[:Gk]}年#{fmt_pat[:Lk]}#{fmt_pat[:Sk]}月#{fmt_pat[:Dk]}日",
      })
      ret = format.to_str.gsub(/%J([fFyYegGoOiImMsSlLdD][kK]?)/) { fmt_pat[$1.to_sym] }
      ret.index("%") or return ret
      to_date.strftime(ret)
    end
  end
end
