# coding: utf-8
require 'wareki/calendar_def'
require 'wareki/era_def'
require 'date'
module Wareki
  GREGORIAN_START = 2405160 # Date.new(1873, 1, 1, Date::GREGORIAN).jd
  GREGORIAN_START_YEAR = 1873
  IMPERIAL_START = 1480041  # Date.new(-660, 2, 11, Date::GREGORIAN).jd
  IMPERIAL_START_YEAR = -660
  DATE_INFINITY = ::Date.new(280000000, 12, 31) # Use 280000000 for jruby limitation...
  YEAR_BY_NUM = Hash[*YEAR_DEFS.map{|y| [y.year, y]}.flatten].freeze
  ERA_BY_NAME = Hash[*(ERA_NORTH_DEFS + ERA_DEFS).map {|g| [g.name, g]}.flatten]
  ERA_BY_NAME['皇紀'] = ERA_BY_NAME['神武天皇即位紀元'] = Era.new('皇紀', -660, 1480041, DATE_INFINITY.jd)
  ERA_BY_NAME['西暦'] = ERA_BY_NAME[''] = Era.new('西暦', 1, 1721424, DATE_INFINITY.jd)
  ERA_BY_NAME.keys.each do |era_name|
    alt_era_name = era_name.tr("宝霊神応暦祥寿斎観寛徳禄万福禎国亀", "寳靈神應曆祥壽斉觀寬德祿萬福禎國龜")
    alt_era_name == era_name and next
    ERA_BY_NAME[alt_era_name] = ERA_BY_NAME[era_name]
  end
  ERA_BY_NAME.freeze
  NUM_CHARS = "零〇一二三四五六七八九十卄廿卅丗卌肆百皕千万億兆0123456789０１２３４５６７８９"
  ALT_MONTH_NAME = %w(睦月 如月 弥生 卯月 皐月 水無月 文月 葉月 長月 神無月 霜月 師走).freeze
  REGEX = %r{^
    (?<era_name>西暦|紀元前|#{ERA_BY_NAME.keys.join('|')})?
    (?:(?<year>[元#{NUM_CHARS}]+)年)?
    (?:(?<is_leap>閏|潤|うるう)?
      (?:(?<month>[正#{NUM_CHARS}]+)月 |
         (?<alt_month>#{ALT_MONTH_NAME.join('|')})))?
    (?:(?<day>[元朔晦#{NUM_CHARS}]+)日)?
  $}x

  class UnsupportedDateRange < StandardError; end

  module_function
  def parse_to_date(str, start = ::Date::ITALY)
    begin
      Date.parse(str).to_date(start)
    rescue ArgumentError => e
      ::Date.parse(str, true, start)
    end
  end
end
