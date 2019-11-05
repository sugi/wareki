# frozen_string_literal: true

require 'wareki/calendar_def'
require 'wareki/era_def'
require 'date'
# Wareki module common constants definitions
module Wareki
  GREGORIAN_START = 2_405_160 # Date.new(1873, 1, 1, Date::GREGORIAN).jd
  GREGORIAN_START_YEAR = 1873
  IMPERIAL_START = 1_480_041  # Date.new(-660, 2, 11, Date::GREGORIAN).jd
  IMPERIAL_START_YEAR = -660
  DATE_INFINITY = ::Date.new(280_000_000, 12, 31) # Use 280000000 for jruby limitation...
  YEAR_BY_NUM = Hash[*YEAR_DEFS.map { |y| [y.year, y] }.flatten].freeze
  KANJI_VARIANTS = {
    '宝' => '寳',
    '霊' => '靈',
    '神' => '神',
    '応' => '應',
    '暦' => '曆',
    '祥' => '祥',
    '寿' => '壽',
    '斎' => '斉',
    '観' => '觀',
    '寛' => '寬',
    '徳' => '德',
    '禄' => '祿',
    '万' => '萬',
    '福' => '福',
    '禎' => '禎',
    '国' => '國',
    '亀' => '龜',
    '令' => '令',
  }.freeze
  SQUARE_ERAS = {
    '㍾' => '明治',
    '㍽' => '大正',
    '㍼' => '昭和',
    '㍻' => '平成',
    '㋿' => '令和',
  }.freeze
  NORMALIZE_KANJI_VARIANTS_REGEX = Regexp.union(*KANJI_VARIANTS.values)
  NORMALIZE_KANJI_VARIANTS_HASH = KANJI_VARIANTS.each_with_object({}) { |(n, s), h| s.each_char { |c| h[c] = n } }
  NORMALIZE_KANJI_VARIANTS = ->(str) { str.gsub(NORMALIZE_KANJI_VARIANTS_REGEX, NORMALIZE_KANJI_VARIANTS_HASH) }
  ERA_BY_NAME = Hash[*(ERA_NORTH_DEFS + ERA_DEFS).flat_map { |g| [g.name, g] }]
  ERA_BY_NAME['皇紀'] = ERA_BY_NAME['神武天皇即位紀元'] = Era.new('皇紀', -660, 1_480_041, DATE_INFINITY.jd)
  ERA_BY_NAME['西暦'] = ERA_BY_NAME[''] = Era.new('西暦', 1, 1_721_424, DATE_INFINITY.jd)
  ERA_BY_NAME.default_proc = ->(hash, key) { hash.fetch(SQUARE_ERAS[key] || NORMALIZE_KANJI_VARIANTS[key], nil) }
  ERA_BY_NAME.freeze
  ERA_REGEX = Regexp.new(
    Regexp.union(*ERA_BY_NAME.keys, *SQUARE_ERAS.keys).source.gsub(
      Regexp.union(*KANJI_VARIANTS.keys),
      KANJI_VARIANTS.each_with_object({}) { |(canon, variants), h| h[canon] = "[#{canon}#{variants}]" }
    )
  )
  NUM_CHARS = '零壱壹弌弐貳貮参參弎肆伍陸漆質柒捌玖〇一二三四五六七八九十拾什卄廿卅丗卌百陌佰皕阡仟千万萬億兆京垓0123456789０１２３４５６７８９'.freeze
  ALT_MONTH_NAME = %w(睦月 如月 弥生 卯月 皐月 水無月 文月 葉月 長月 神無月 霜月 師走).freeze
  REGEX = %r{
    (?:(?<era_name>紀元前|#{ERA_REGEX})?
      (?:(?<year>[元#{NUM_CHARS}]+)年))?
    (?:(?<is_leap>閏|潤|うるう)?
      (?:(?<month>[正#{NUM_CHARS}]+)月 |
         (?<alt_month>#{ALT_MONTH_NAME.join('|')})))?
    (?:(?<day>[元朔晦#{NUM_CHARS}]+)日|元旦)?
  }x.freeze

  class UnsupportedDateRange < StandardError; end

  module_function

  def parse_to_date(str, start = ::Date::ITALY)
    Date.parse(str).to_date(start)
  rescue ArgumentError
    ::Date.parse(str, true, start)
  end
end
