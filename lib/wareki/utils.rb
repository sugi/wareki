# coding: utf-8
module Wareki
  module Utils
    module_function
    def kan_to_i(str)
      ret3 = 0
      ret4 = 0
      curnum = nil
      str == "零" and return 0
      str.to_s.each_char do |c|
        case c
        when *%w(正 元 朔 一 二 三 四 五 六 七 八 九 肆 1 2 3 4 5 6 7 8 9 １ ２ ３ ４ ５ ６ ７ ８ ９)
          if curnum
            curnum *= 10
          else
            curnum = 0
          end
          curnum += c.tr("一二三四五六七八九１２３４５６７８９肆元朔正", "1234567891234567894111").to_i
        when "〇", "０", "0"
          curnum and curnum *= 10
        when "卄", "廿"
          ret3 += 20
          curnum = nil
        when "卅", "丗"
          ret3 += 30
          curnum = nil
        when "卌"
          ret3 += 40
          curnum = nil
        when "皕"
          ret3 += 200
          curnum = nil
        when "万", "億", "兆", "京", "垓"
          if curnum
            ret3 += curnum
            curnum = nil
          end
          ret3 = 1 if ret3 == 0
          ret4 += ret3 * 10 ** ((["万", "億", "兆", "京", "垓"].index(c)+1)*4)
          ret3 = 0
        when "十", "百", "千"
          curnum ||= 1
          ret3 += curnum * 10 ** (["十", "百", "千"].index(c)+1)
          curnum = nil
        end
      end
      if curnum
        ret3 += curnum
        curnum = nil
      end
      ret4 + ret3
    end

    def i_to_kan(num, opts = {})
      ret = ''
      {
        '京' => 10000000000000000,
        '兆' => 1000000000000,
        '億' => 100000000,
        '万' => 10000,
        ''   => 1,
      }.each do |unit4, rank4|
        i4 = (num / rank4).to_i % 10000
        if i4 == 0
          next
        elsif i4 == 1
          ret += "一#{unit4}"
          next
        end
        {
          '千' => 1000,
          '百' => 100,
          '十' => 10,
          ''   => 1,
        }.each do |unit1, rank1|
          i1 = (i4 / rank1).to_i % 10
          if i1 == 0
            next
          elsif i1 == 1 && unit1 != ""
            ret += unit1
          else
            ret += i1.to_s.tr('123456789', '一二三四五六七八九') + unit1
          end
        end
        ret += unit4
      end
      ret
    end

    def i_to_zen(num)
      num.to_s.tr('0123456789', '０１２３４５６７８９')
    end

    def last_day_of_month(year, month, is_leap)
      if year >= GREGORIAN_START_YEAR
        tmp_y = year
        tmp_m = month
        if month == 12
          tmp_y += 1
          tmp_m = 1
        else
          tmp_m += 1
        end
        day = (::Date.new(tmp_y, tmp_m, 1, ::Date::GREGORIAN)-1).day
      else
        yobj = YEAR_BY_NUM[year] or
          raise UnsupportedDateRange, "Cannot find year #{self.inspect}"
        month_idx = month - 1
        if is_leap || yobj.leap_month && yobj.leap_month < month
          month_idx += 1
        end
        day = yobj.month_days[month_idx]
      end
      day
    end

    def alt_month_name_to_i(name)
      i = ALT_MONTH_NAME.index(name) or return false
      i + 1
    end

    def alt_month_name(month)
      ALT_MONTH_NAME[month - 1]
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
      YEAR_DEFS.bsearch{|y| y.end >= jd }
    end

    def find_era(d)
      jd = _to_jd(d)
      ERA_DEFS.reverse_each { |e|
        e.start > jd and next
        e.end < jd and next
        return e
      }
      return nil
    end
  end
end
