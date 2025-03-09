# frozen_string_literal: true

require 'date'
require 'ya_kansuji'
require 'wareki/common'
require 'wareki/utils'
require 'wareki/kansuji'
module Wareki
  # Wareki date handling class, main implementation.
  class Date
    attr_accessor :year, :month, :day, :era_year, :era_name

    def self.today
      jd(::Date.today.jd)
    end

    def self._check_invalid_date(era, year, month, day)
      month == 12 or return true
      day > 2 or return true
      (era == '明治' && year == 5 ||
       %w(皇紀 神武天皇即位紀元).member?(era) &&
       year == GREGORIAN_START_YEAR - IMPERIAL_START_YEAR - 1) and
        return false
      true
    end

    def self._parse(str)
      str = str.to_s.gsub(/[[:space:]]/, '')
      match = REGEX.match(str)
      match && !match[0].empty? or
        raise ArgumentError, "Invaild Date: #{str}"
      era = match[:era_name]
      if (era.nil? || era == '') && match[:year].nil?
        year = Date.today.year
      else
        (year = Utils.k2i(match[:year])) > 0 or
          raise ArgumentError, "Invalid year: #{str}"
      end
      month = day = 1

      era.to_s != '' && era.to_s != '紀元前' && !ERA_BY_NAME[era] and
        raise ArgumentError, "Date parse failed: Invalid era name '#{match[:era_name]}'"

      if match[:month]
        month = Utils.k2i(match[:month])
      elsif match[:alt_month]
        month = Utils.alt_month_name_to_i(match[:alt_month])
      end

      month > 12 || month < 1 and
        raise ArgumentError, "Invalid month: #{str}"

      if match[:day]
        if match[:day] == '晦'
          day = Utils.last_day_of_month(ERA_BY_NAME[era].year + year - 1, month, match[:is_leap])
        else
          day = Utils.k2i(match[:day])
        end
      end

      _check_invalid_date(era, year, month, day) or
        raise ArgumentError, "Invaild Date: #{str}"

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
      new('皇紀', year, month, day, is_leap_month)
    end

    def initialize(era_name, era_year, month = 1, day = 1, is_leap_month = false)
      raise ArgumentError, "Undefined era '#{era_name}'" if
        era_name.to_s != '' && era_name != '紀元前' && !ERA_BY_NAME[era_name]

      @month = month
      @day = day
      @is_leap_month = is_leap_month
      @era_name = era_name
      @era_year = era_year
      if era_name.to_s == '' || era_name == '西暦'
        @year = @era_year
      elsif era_name.to_s == '紀元前'
        @year = -@era_year
      elsif %w(皇紀 神武天皇即位紀元).include? era_name
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
      return month - 1 if
        ['', '西暦', '紀元前'].include?(@era_name) || @year >= GREGORIAN_START_YEAR

      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot get year info of #{inspect}"
      idx = month - 1
      idx += 1 if leap_month? || yobj.leap_month && month > yobj.leap_month
      idx
    end

    def jd
      @jd and return @jd

      ['', '西暦', '紀元前'].include?(@era_name) and
        return @jd = ::Date.new(@year, month, day, ::Date::ITALY).jd

      @year >= GREGORIAN_START_YEAR and
        return @jd = ::Date.new(@year, month, day, ::Date::GREGORIAN).jd

      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot convert to jd #{inspect}"
      @jd = yobj.month_starts[month_index] + day - 1
    end

    def to_date(start = ::Date::ITALY)
      ::Date.jd(jd, start)
    end

    def to_time
      to_date.to_time
    end

    def strftime(format_str = '%JF')
      ret = format_str.to_str.gsub(/%J(-|[_0]{0,2}[0-9]*|)([fFyYegGoOiImMsSlLdD][kK]?)/) { format($2, $1) || $& }
      ret.index('%') or return ret
      d = to_date
      d.respond_to?(:_wareki_strftime_orig) ? d._wareki_strftime_orig(ret) : d.strftime(ret)
    end

    def _number_format(opt)
      case opt
      when ''    then '%02d'
      when '-'   then '%d'
      when '0'   then '%02d'
      when '_0'  then '%02d'
      when /_\Z/ then '%2d'
      when /0?_/ then "\%#{opt.sub(/0?_/, '')}d"
      when /_?0/ then "\%#{opt.sub(/_?0/, '0')}d"
      else "\%0#{opt}d"
      end
    end

    def format(key, opt = '')
      case key.to_sym
      when :e  then era_name
      when :g  then era_name.to_s == '' ? '' : Kernel.format(_number_format(opt), era_year)
      when :G  then era_name.to_s == '' ? '' : Utils.i2z(era_year)
      when :Gk then era_name.to_s == '' ? '' : YaKansuji.to_kan(era_year, :simple)
      when :GK
        if era_name.to_s == ''
          ''
        elsif era_year == 1
          '元'
        else
          YaKansuji.to_kan(era_year, :simple)
        end
      when :o  then year
      when :O  then Utils.i2z(year)
      when :Ok then YaKansuji.to_kan(year, :simple)
      when :i  then imperial_year
      when :I  then Utils.i2z(imperial_year)
      when :Ik then YaKansuji.to_kan(imperial_year, :simple)
      when :s  then Kernel.format(_number_format(opt), month)
      when :S  then Utils.i2z(month)
      when :Sk then YaKansuji.to_kan(month, :simple)
      when :SK then Utils.alt_month_name(month)
      when :l  then leap_month? ? "'" : ''
      when :L  then leap_month? ? '’' : ''
      when :Lk then leap_month? ? '閏' : ''
      when :d  then Kernel.format(_number_format(opt), day)
      when :D  then Utils.i2z(day)
      when :Dk then YaKansuji.to_kan(day, :simple)
      when :DK
        if month == 1 && !leap_month? && day == 1
          '元'
        elsif day == 1
          '朔'
        elsif day == Utils.last_day_of_month(year, month, leap_month?)
          '晦'
        else
          YaKansuji.to_kan(day, :simple)
        end
      when :m  then "#{format(:s, opt)}#{format(:l)}"
      when :M  then "#{format(:Lk)}#{format(:S)}"
      when :Mk then "#{format(:Lk)}#{format(:Sk)}"
      when :y  then "#{format(:e)}#{format(:g, opt)}"
      when :Y  then "#{format(:e)}#{format(:G)}"
      when :Yk then "#{format(:e)}#{format(:Gk)}"
      when :YK then "#{format(:e)}#{format(:GK)}"
      when :f  then "#{format(:e)}#{format(:g, opt)}年#{format(:s, opt)}#{format(:l)}月#{format(:d, opt)}日"
      when :F  then "#{format(:e)}#{format(:GK)}年#{format(:Lk)}#{format(:Sk)}月#{format(:Dk)}日"
      end
    end

    def eql?(other)
      begin
        %i[year month day era_year era_name leap_month?].each do |attr|
          other.public_send(attr) == public_send(attr) or return false
        end
      rescue NoMethodError, NotImplementedError
        return false
      end
      true
    end
    alias == eql?

    def ===(other)
      begin
        other.jd == jd or return false
      rescue NoMethodError, NotImplementedError
        return false
      end
      true
    end

    def -(other)
      self.class.jd jd - _to_jd_for_calc(other)
    end

    def +(other)
      self.class.jd jd + _to_jd_for_calc(other)
    end

    def _to_jd_for_calc(other)
      other.class.to_s == 'ActiveSupport::Duration' and
        raise NotImplementedError, 'Date calcration with ActiveSupport::Duration currently is not supported. Please use numeric.'
      other.respond_to?(:to_date) and other = other.to_date
      other.respond_to?(:jd) and other = other.jd
      other
    end
  end
end
