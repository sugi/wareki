# frozen_string_literal: true

require 'wareki/calendar_def'

module Wareki
  # 旧暦テーブルの参照ロジック。1年分の旧暦情報は整数1個 (40bit) に
  # ビットパックされている。PACKED[西暦年 - YEAR_MIN]:
  #   bits 0..21  : その年の最初の月の初日のユリウス通日 (JD)
  #   bits 22..34 : 月の大小マスク (bit i = i 番目の月が大の月 = 30日)
  #   bit  35     : 閏月を含む13ヶ月の年なら1
  #   bits 36..39 : 閏月の月番号 (1..12、閏月がなければ0)
  # 明治5年12月 (テーブル最終月) はグレゴリオ暦切替のため LAST_MONTH_DAYS
  # (= 2) 日で打ち切られており、大小マスクには反映されていない。
  module Calendar
    # 一時ブートストラップ: 旧形式 YEAR_DEFS から詰め替えて定数を構築する。
    # build-util/gen-jp-cal-def.rb が生成する新形式 calendar_def.rb に置換予定。
    YEAR_MIN = YEAR_DEFS.first.year
    YEAR_MAX = YEAR_DEFS.last.year
    JD_MIN = YEAR_DEFS.first.month_starts.first
    JD_MAX = YEAR_DEFS.last.end
    LAST_MONTH_DAYS = YEAR_DEFS.last.month_days.last
    PACKED = YEAR_DEFS.map do |y|
      mask = 0
      y.month_days.each_with_index { |d, i| mask |= (1 << i) if d == 30 }
      ((y.leap_month || 0) << 36) | ((y.month_starts.size - 12) << 35) |
        (mask << 22) | y.month_starts.first
    end.freeze
    # ブートストラップここまで

    module_function

    def covers_year?(year)
      year.between?(YEAR_MIN, YEAR_MAX)
    end

    def covers_jd?(jd)
      jd.between?(JD_MIN, JD_MAX)
    end

    # 閏月の月番号。閏月のない年・範囲外の年は nil
    def leap_month(year)
      covers_year?(year) or return nil
      lp = PACKED[year - YEAR_MIN] >> 36
      lp == 0 ? nil : lp
    end

    # 月番号 (1始まり) を月配列添字 (閏月込み・0始まり) に変換する。
    # year がテーブル範囲内であることは呼び出し側が保証すること。
    def month_index(year, month, is_leap)
      lp = leap_month(year)
      idx = month - 1
      is_leap || (lp && month > lp) and idx += 1
      idx
    end

    def last_day_of_month(year, month, is_leap)
      covers_year?(year) or return nil
      packed = PACKED[year - YEAR_MIN]
      idx = month_index(year, month, is_leap)
      months = 12 + ((packed >> 35) & 1)
      return LAST_MONTH_DAYS if year == YEAR_MAX && idx == months - 1

      29 + ((packed >> (22 + idx)) & 1)
    end

    def to_jd(year, month, day, is_leap)
      covers_year?(year) or return nil
      packed = PACKED[year - YEAR_MIN]
      idx = month_index(year, month, is_leap)
      jd = packed & 0x3fffff
      i = 0
      while i < idx
        jd += 29 + ((packed >> (22 + i)) & 1)
        i += 1
      end
      jd + day - 1
    end

    # jd を [西暦年, 月, 日, 閏月フラグ] に変換する。範囲外は nil
    def find_date_ary(jd)
      covers_jd?(jd) or return nil
      i = PACKED.bsearch_index { |packed| (packed & 0x3fffff) > jd }
      if i.nil?
        i = PACKED.size - 1
      else
        i -= 1
      end
      packed = PACKED[i]
      month_start = packed & 0x3fffff
      months = 12 + ((packed >> 35) & 1)
      lp = packed >> 36
      idx = 0
      while idx < months - 1
        next_start = month_start + 29 + ((packed >> (22 + idx)) & 1)
        break if jd < next_start

        month_start = next_start
        idx += 1
      end
      month = idx + 1
      month -= 1 if lp != 0 && lp < month
      [YEAR_MIN + i, month, jd - month_start + 1, lp != 0 && lp == idx]
    end
  end
end
