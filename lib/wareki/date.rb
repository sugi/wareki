# coding: utf-8
require 'date'
require 'wareki/common'
require 'wareki/utils'
module Wareki
  class Date
    attr_reader :jd
    attr_accessor :year, :month, :day, :era_year, :era_name

    def self.today
      jd(::Date.today.jd)
    end

    def self._parse(str)
      match = REGEX.match(str.to_s.gsub(/[[:space:]]/, ''))
      if !match || !match[:year]
        raise ArgumentError, "Invaild Date: #{str}"
      end
      era = match[:era_name]
      year = Utils.kan_to_i(match[:year])
      month = 1
      day = 1

      if era.to_s != "" && era.to_s != "紀元前" && !ERA_BY_NAME[era]
        raise ArgumentError, "Date parse failed: Invalid era name '#{match[:era_name]}'"
      end

      if match[:month]
        month = Utils.kan_to_i(match[:month])
      elsif match[:alt_month]
        month = Utils.alt_month_name_to_i(match[:alt_month])
      end

      month > 12 || month < 0 and
        raise ArgumentError, "Invalid month: #{str}"

      if match[:day]
        if match[:day] == "晦"
          day = Utils.last_day_of_month(ERA_BY_NAME[era].year + year -1, month, match[:is_leap])
        else
          day = Utils.kan_to_i(match[:day])
        end
      end

      if (era == "明治" && year == 5 ||
          era.to_s == "" && year == GREGORIAN_START_YEAR - 1 ||
          (era == "皇紀" || era == "神武天皇即位紀元") &&
          year == GREGORIAN_START_YEAR - IMPERIAL_START_YEAR - 1) &&
          month == 12 && day > 2
        raise ArgumentError, "Invaild Date: #{str}"
      end

      {era: era, year: year, month: month, day: day, is_leap: !!match[:is_leap]}
    end

    def self.parse(str)
      di = _parse(str)
      new(di[:era], di[:year], di[:month], di[:day], di[:is_leap])
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
      if era_name.to_s != "" && era_name != "紀元前" && !ERA_BY_NAME[era_name]
        raise ArgumentError, "Undefined era '#{era_name}'"
      end
      @month = month
      @day = day
      @is_leap_month = is_leap_month
      @era_name = era_name
      @era_year = era_year
      if era_name.to_s == "" || era_name == "西暦"
        @year = @era_year
      elsif era_name == "皇紀" || era_name == "神武天皇即位紀元"
        @year = era_year + IMPERIAL_START_YEAR
      elsif era_name.to_s == "紀元前"
        @year = -@era_year
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
      if @era_name == "" || @era_name == "西暦" || @era_name == "紀元前" || @year >= GREGORIAN_START_YEAR
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

      if @era_name == "西暦" || @era_name == "" || @era_name == "紀元前"
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

    def to_time
      to_date.to_time
    end

    def strftime(format_str = "%JF")
      ret = format_str.to_str.gsub(/%J([fFyYegGoOiImMsSlLdD][kK]?)/) { format($1) || $& }
      ret.index("%") or return ret
      d = to_date
      d.respond_to?(:_wareki_strftime_orig) ? d._wareki_strftime_orig(ret) : d.strftime(ret)
    end

    def format(key)
      case key.to_sym
      when :e; era_name
      when :g; era_name.to_s == "" ? '' : era_year
      when :G; era_name.to_s == "" ? '' : Utils.i_to_zen(era_year)
      when :Gk; era_name.to_s == "" ? '' : Utils.i_to_kan(era_year)
      when :GK
        if era_name.to_s == ""
          ''
        elsif era_year == 1
          "元"
        else
          Utils.i_to_kan(era_year)
        end
      when :o; year
      when :O; Utils.i_to_zen(year)
      when :Ok; Utils.i_to_kan(year)
      when :i; imperial_year
      when :I; Utils.i_to_zen(imperial_year)
      when :Ik; Utils.i_to_kan(imperial_year)
      when :s; month
      when :S; Utils.i_to_zen(month)
      when :Sk; Utils.i_to_kan(month)
      when :SK; Utils.alt_month_name(month)
      when :l; leap_month? ? "'" : ""
      when :L; leap_month? ? "’" : ""
      when :Lk; leap_month? ? "閏" : ""
      when :d; day
      when :D; Utils.i_to_zen(day)
      when :Dk; Utils.i_to_kan(day)
      when :DK
        if month == 1 && !leap_month? && day == 1
          "元"
        elsif day == 1
          "朔"
        elsif day == Utils.last_day_of_month(year, month, leap_month?)
          "晦"
        else
          Utils.i_to_kan(day)
        end
      when :m; "#{format(:s)}#{format(:l)}"
      when :M; "#{format(:Lk)}#{format(:S)}"
      when :Mk; "#{format(:Lk)}#{format(:Sk)}"
      when :y; "#{format(:e)}#{format(:g)}"
      when :Y; "#{format(:e)}#{format(:G)}"
      when :Yk; "#{format(:e)}#{format(:Gk)}"
      when :YK; "#{format(:e)}#{format(:GK)}"
      when :f; "#{format(:e)}#{format(:g)}年#{format(:s)}#{format(:l)}月#{format(:d)}日"
      when :F; "#{format(:e)}#{format(:GK)}年#{format(:Lk)}#{format(:Sk)}月#{format(:Dk)}日"
      else
        nil
      end
    end

    def eql?(other)
      begin
        [:year, :month, :day, :era_year, :era_name, :leap_month?].each do |attr|
          other.public_send(attr) == public_send(attr) or return false
        end
      rescue => e
        return false
      end
      true
    end
    alias_method :==, :eql?

    def ===(other)
      begin
        other.jd == jd or return false
      rescue => e
        return false
      end
      true
    end

    def -(other)
      if other.class.to_s == "ActiveSupport::Duration"
        raise NotImplementedError, "Date calcration with ActiveSupport::Duration currently is not supported. Please use numeric."
      else
        other.respond_to?(:to_date) and other = other.to_date
        other.respond_to?(:jd) and other = other.jd
        self.class.jd jd - other
      end
    end

    def +(other)
      if other.class.to_s == "ActiveSupport::Duration"
        raise NotImplementedError, "Date calcration with ActiveSupport::Duration currently is not supported. Please use numeric."
      else
        other.respond_to?(:to_date) and other = other.to_date
        other.respond_to?(:jd) and other = other.jd
        self.class.jd jd + other
      end
    end
  end
end
