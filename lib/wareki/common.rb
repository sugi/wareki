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
  WESTERN_ERA_NAMES = ['', '西暦', '紀元前'].freeze
  IMPERIAL_ERA_NAMES = %w(皇紀 神武天皇即位紀元).freeze
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
  ERA_BY_NAME['皇紀'] = ERA_BY_NAME['神武天皇即位紀元'] = Era.new('皇紀', -660, 1_480_041, DATE_INFINITY.jd).freeze
  ERA_BY_NAME['西暦'] = ERA_BY_NAME[''] = Era.new('西暦', 1, 1_721_424, DATE_INFINITY.jd).freeze
  ERA_BY_NAME.default_proc = ->(hash, key) { hash.fetch(SQUARE_ERAS[key] || NORMALIZE_KANJI_VARIANTS[key], nil) }
  ERA_BY_NAME.freeze
  # 南北朝期に北朝でのみ使われた元号。歴史上固定のため手書きで保持する。
  # jd からの元号解決では README の記載どおり南朝を優先し、これらは索引から
  # 除外する (名前からの解釈・変換は ERA_BY_NAME で引き続き可能)。
  NORTH_COURT_ERA_NAMES = %w(正慶 暦応 康永 貞和 観応 文和 延文 康安 貞治
                             応安 永和 康暦 永徳 至徳 嘉慶 康応).freeze
  ERA_JD_LOOKUP = begin
    eras = ERA_DEFS.reject { |e| NORTH_COURT_ERA_NAMES.include?(e.name) }.map(&:dup)
    meitoku = eras.find { |e| e.name == '明徳' }
    gencyu = eras.find { |e| e.name == '元中' }
    # 明徳(北朝発祥)は南北朝合一で継続元号になるため、元中の終端以降のみ充てる
    meitoku.start = gencyu.end
    eras.sort_by!(&:start)
    # 重複・境界共有は後続元号を優先 (従来の reverse_each と同じ規則)
    eras.each_cons(2) { |a, b| a.end = b.start - 1 if a.end >= b.start }
    eras.each(&:freeze)
    eras.freeze
  end
  ERA_REGEX = Regexp.new(
    Regexp.union(*ERA_BY_NAME.keys, *SQUARE_ERAS.keys).source.gsub(
      Regexp.union(*KANJI_VARIANTS.keys),
      KANJI_VARIANTS.each_with_object({}) { |(canon, variants), h| h[canon] = "[#{canon}#{variants}]" }
    )
  )
  NUM_CHARS = '零壱壹弌弐貳貮参參弎肆伍陸漆質柒捌玖〇一二三四五六七八九十拾什卄廿卅丗卌百陌佰皕阡仟千万萬億兆京垓0123456789０１２３４５６７８９'
  ALT_MONTH_NAME = %w(睦月 如月 弥生 卯月 皐月 水無月 文月 葉月 長月 神無月 霜月 師走).freeze
  REGEX = %r{
    (?:(?<era_name>紀元前|#{ERA_REGEX})?
      (?:(?<year>[元#{NUM_CHARS}]+)年))?
    (?:(?<is_leap>閏|潤|うるう)?
      (?:(?<month>[正#{NUM_CHARS}]+)(?<is_leap_post>['’])?月 |
         (?<alt_month>#{ALT_MONTH_NAME.join('|')})))?
    (?:(?<day>[元朔晦#{NUM_CHARS}]+)日|元旦)?
  }x.freeze
  # REGEX が空でないマッチを返すには 年/月/日/元旦 か、「月」を含まない
  # 月の別名 (弥生・師走) のいずれかが必要。それ以外は素の Date.parse に
  # 直行させて monkey patch のオーバーヘッドを避ける。
  PARSE_QUICK_FILTER = /[年月日]|元旦|弥生|師走/.freeze

  class UnsupportedDateRange < StandardError; end
  class InvalidDate < ArgumentError; end

  module_function

  def parse_to_date(str, start = ::Date::ITALY)
    Date.parse(str).to_date(start)
  rescue InvalidDate
    raise
  rescue ArgumentError, UnsupportedDateRange
    ::Date.parse(str, true, start)
  end
end
