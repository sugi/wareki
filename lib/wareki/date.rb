# frozen_string_literal: true

require 'date'
require 'ya_kansuji'
require 'wareki/common'
require 'wareki/utils'
require 'wareki/kansuji'
module Wareki
  # Wareki date handling class, main implementation.
  class Date
    include Comparable

    attr_reader :year, :month, :day, :era_year, :era_name

    def self.today
      jd(::Date.today.jd)
    end

    def self._parse(str)
      str = str.to_s.gsub(/[[:space:]]/, '')
      match = REGEX.match(str)
      (match && !match[0].empty?) or
        raise ArgumentError, "Invaild Date: #{str}"
      era = match[:era_name]
      if (era.nil? || era == '') && match[:year].nil?
        year = Date.today.year
      else
        year = Utils.k2i(match[:year])
        year > 0 or raise ArgumentError, "Invalid year: #{str}"
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
        raise InvalidDate, "invalid date (month out of range): #{str}"

      is_leap = !!(match[:is_leap] || match[:is_leap_post])

      if match[:day]
        if match[:day] == '晦'
          civil_year = Utils.era_year_to_civil(era, year)
          day = Utils.last_day_of_era_month(era, civil_year, month, is_leap)
        else
          day = Utils.k2i(match[:day])
        end
      end

      {era: era, year: year, month: month, day: day, is_leap: is_leap}
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
      @era_name = era_name.to_s
      @era_year = era_year
      @month = month
      @day = day
      @is_leap_month = is_leap_month
      @year = Utils.era_year_to_civil(@era_name, @era_year)
      _validate_date!
    end

    def imperial_year
      @year - IMPERIAL_START_YEAR
    end

    def imperial_year=(v)
      self.year = v + IMPERIAL_START_YEAR
    end

    def leap_month?
      !!@is_leap_month
    end

    def leap_month=(v)
      @jd = nil
      @is_leap_month = v
    end

    def year=(v)
      era_year = Utils.civil_to_era_year(@era_name, v)
      @jd = nil
      @year = v
      @era_year = era_year
    end

    def month=(v)
      @jd = nil
      @month = v
    end

    def day=(v)
      @jd = nil
      @day = v
    end

    def era_year=(v)
      year = Utils.era_year_to_civil(@era_name, v)
      @jd = nil
      @era_year = v
      @year = year
    end

    def era_name=(v)
      era_name = v.to_s
      year = Utils.era_year_to_civil(era_name, @era_year)
      @jd = nil
      @era_name = era_name
      @year = year
    end

    def __set_jd(v)
      @jd = v
    end

    def month_index
      return month - 1 if
        WESTERN_ERA_NAMES.include?(@era_name) || @year >= GREGORIAN_START_YEAR

      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot get year info of #{inspect}"
      idx = month - 1
      idx += 1 if leap_month? || (yobj.leap_month && month > yobj.leap_month)
      idx
    end

    def last_day_of_month
      Utils.last_day_of_era_month(@era_name, @year, month, leap_month?)
    end

    def _validate_date!
      (month.is_a?(Integer) && month >= 1 && month <= 12) or
        raise InvalidDate, "invalid date (month out of range): #{inspect}"
      (day.is_a?(Integer) && day >= 1) or
        raise InvalidDate, "invalid date (day out of range): #{inspect}"
      if !WESTERN_ERA_NAMES.include?(@era_name) && @year < GREGORIAN_START_YEAR
        # 暦テーブル外の年は従来どおり jd 変換時の UnsupportedDateRange に委ねる
        yobj = YEAR_BY_NUM[@year] or return
        !leap_month? || yobj.leap_month == month or
          raise InvalidDate, "invalid date (no leap month): #{inspect}"
        day <= yobj.month_days[month_index] or
          raise InvalidDate, "invalid date (day out of range): #{inspect}"
      else
        leap_month? and
          raise InvalidDate, "invalid date (no leap month): #{inspect}"
        day <= last_day_of_month or
          raise InvalidDate, "invalid date (day out of range): #{inspect}"
      end
    end

    def jd
      @jd and return @jd

      _validate_date!
      WESTERN_ERA_NAMES.include?(@era_name) and
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

    FORMAT_DIRECTIVE_REGEX = /%J(-|[_0]{0,2}[0-9]*|)([fFyYegGoOiImMsSlLdD][kK]?)/.freeze
    FORMAT_EXPANSION_REGEX = /(?<!%)(?:%%)*\K#{FORMAT_DIRECTIVE_REGEX}/.freeze

    def expand_wareki_format(format_str)
      format_str.to_str.gsub(FORMAT_EXPANSION_REGEX) { format($2, $1) || $& }
    end

    def strftime(format_str = '%JF')
      ret = expand_wareki_format(format_str)
      ret.index('%') or return ret
      d = to_date
      d.respond_to?(:_wareki_strftime_orig) ? d._wareki_strftime_orig(ret) : d.strftime(ret)
    end

    def _number_format(opt)
      Utils.number_format(opt)
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
        elsif day == last_day_of_month
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

    def hash
      [self.class, @era_name, @era_year, @year, @month, @day, leap_month?].hash
    end

    def <=>(other)
      ojd = _jd_if_date_like(other)
      ojd = other if ojd.nil? && other.is_a?(Numeric)
      ojd.nil? and return nil
      jd <=> ojd
    end

    def succ
      self + 1
    end

    def -(other)
      n = _to_days(other)
      n.nil? or return self.class.jd(jd - n)
      ojd = _jd_if_date_like(other)
      ojd and return jd - ojd
      raise TypeError, "Cannot subtract #{other.inspect} from Wareki::Date"
    end

    def +(other)
      n = _to_days(other)
      n.nil? and raise TypeError, "Cannot add #{other.inspect} to Wareki::Date"
      self.class.jd(jd + n)
    end

    def _to_days(other)
      # rubocop:disable Style/ClassEqualityComparison
      return other.in_days if other.class.name == 'ActiveSupport::Duration'
      # rubocop:enable Style/ClassEqualityComparison

      other.is_a?(Numeric) ? other : nil
    end

    def _jd_if_date_like(other)
      return other.jd if other.respond_to?(:jd)

      other.respond_to?(:to_date) && !other.is_a?(Numeric) and other = other.to_date
      other.respond_to?(:jd) ? other.jd : nil
    end
  end
end
