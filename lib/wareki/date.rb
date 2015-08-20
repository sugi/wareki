# coding: utf-8
require 'wareki/common'
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
          if year >= GREGORIAN_START_YEAR
            tmp_y = year
            tmp_m = month
            if month == 12
              tmp_y += 1
              tmp_m = 1
            else
              tmp_m += 1
            end
            day = (::Date.new(tmp_y, tmp_m, 1, Date::GREGORIAN)-1).day
          else
            yobj = Utils.find_year(year)
            month_idx = month - 1
            if match[:is_leap] || yobj.leap_month && yobj.leap_month < month
              month_idx += 1
            end
            day = yobj.month_days[month_idx]
          end
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

    def jd
      @jd and return @jd

      if @era_name == "西暦"
        return @jd = ::Date.new(@year, month, day, ::Date::ITALY).jd
      elsif @year >= GREGORIAN_START_YEAR
        return @jd = ::Date.new(@year, month, day, ::Date::GREGORIAN).jd
      end

      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot convert to jd #{self.inspect}"
      month_idx = month - 1
      if leap_month? || yobj.leap_month && month > yobj.leap_month
        month_idx += 1
      end
      @jd = yobj.month_starts[month_idx] + day - 1
    end

    def to_date(start = ::Date::ITALY)
      ::Date.jd(jd, start)
    end

    def __set_jd(v)
      @jd = v
    end
  end
end
