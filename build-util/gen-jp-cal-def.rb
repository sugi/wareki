#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Usage: ruby build-util/gen-jp-cal-def.rb kyuureki-map.txt > lib/wareki/calendar_def.rb
#
# You can get kyuureki-map.txt from
# https://raw.githubusercontent.com/manakai/data-locale/master/data/calendar/kyuureki-map.txt
#
# 出力は「1年 = 整数1個 (40bit)」のビットパック表現。
# レイアウトは lib/wareki/calendar.rb のコメントを参照。
#
require 'date'

YEAR_MIN = 445

calinfo = Hash.new { |h, k| h[k] = {month_starts: [], month_days: []} }

ARGF.each do |line|
  line =~ /^(?<gy>[0-9]+)-(?<gm>[0-9]+)-(?<gd>[0-9]+)\s+(?<jy>[0-9]+)-(?<jm>[0-9]+)(?<jl>')?-(?<jd>[0-9]+)/ or next
  gdate = Date.new($~[:gy].to_i, $~[:gm].to_i, $~[:gd].to_i, Date::GREGORIAN)
  gdate.year == 1873 and break
  year  = $~[:jy].to_i
  month = $~[:jm].to_i
  leap  = !!$~[:jl]
  cy = calinfo[year]
  if $~[:jd].to_i == 1
    cy[:month_starts] << gdate.jd
    if leap
      cy[:leap] and raise "#{year} already has leap month (#{cy[:leap]} vs #{month})"
      cy[:leap] = month
    end
  end
  cy[:month_days][cy[:month_starts].count - 1] = gdate.jd - cy[:month_starts].last + 1
end

years = calinfo.keys.select { |y| y >= YEAR_MIN }.sort
years == (years.first..years.last).to_a or raise 'years are not contiguous'

packed_list = []
prev_end = nil
years.each do |y|
  d = calinfo[y]
  ms = d[:month_starts]
  days = d[:month_days]
  ms.size == days.size or raise "year #{y}: month starts/days count mismatch"
  [12, 13].include?(ms.size) or raise "year #{y}: unexpected month count #{ms.size}"
  (ms.size == 13) == !d[:leap].nil? or raise "year #{y}: leap flag inconsistent with month count"
  d[:leap].nil? || (1..12).cover?(d[:leap]) or raise "year #{y}: leap month out of range"
  prev_end.nil? || ms.first == prev_end + 1 or raise "year #{y}: calendar not contiguous"
  ms.first < (1 << 22) or raise "year #{y}: JD overflows 22bit"
  ms.each_cons(2).zip(days).all? { |(a, b), dd| b - a == dd } or
    raise "year #{y}: month days inconsistent with month starts"
  days[0..-2].all? { |dd| dd == 29 || dd == 30 } or raise "year #{y}: month days out of range"
  y == years.last || days.last == 29 || days.last == 30 or raise "year #{y}: month days out of range"
  mask = 0
  days.each_with_index { |dd, i| mask |= (1 << i) if dd == 30 }
  packed_list << ((d[:leap] || 0) << 36 | (ms.size - 12) << 35 | mask << 22 | ms.first)
  prev_end = ms.last + days.last - 1
end

puts <<~HEADER
  # frozen_string_literal: true

  # 旧暦カレンダー定義データ (#{years.first}年-#{years.last}年)。
  # build-util/gen-jp-cal-def.rb による自動生成。手動編集しないこと。
  # 再生成: ruby build-util/gen-jp-cal-def.rb kyuureki-map.txt > lib/wareki/calendar_def.rb
  # 元データ: https://raw.githubusercontent.com/manakai/data-locale/master/data/calendar/kyuureki-map.txt
  # 各要素のビットレイアウトは lib/wareki/calendar.rb のコメントを参照。
  module Wareki
    module Calendar
      YEAR_MIN = #{years.first}
      YEAR_MAX = #{years.last}
      JD_MIN = #{calinfo[years.first][:month_starts].first}
      JD_MAX = #{prev_end}
      LAST_MONTH_DAYS = #{calinfo[years.last][:month_days].last}
      PACKED = [
HEADER
packed_list.each_slice(6) do |slice|
  puts "        #{slice.map { |p| format('0x%010x', p) }.join(', ')},"
end
puts <<~FOOTER
      ].freeze
    end
  end
FOOTER
