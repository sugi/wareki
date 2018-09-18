module Wareki
  # Utilities of kansuji/integer converter.
  module Kansuji
    UNIT_SUFFIX1 = {
      '千' => 1000,
      '百' => 100,
      '十' => 10,
      '' => 1,
    }.freeze
    UNIT_SUFFIX2 = {
      '京' => 10_000_000_000_000_000,
      '兆' => 1_000_000_000_000,
      '億' => 100_000_000,
      '万' => 10_000,
      '' => 1,
    }.freeze

    module_function

    def kan_to_i(str)
      ret3 = 0
      ret4 = 0
      curnum = nil
      str == '零' and return 0
      str.to_s.each_char do |c|
        case c
        when '正', '元', '朔',
          '一', '二', '三', '四', '五', '六', '七', '八', '九', '肆',
          '1', '2', '3', '4', '5', '6', '7', '8', '9',
          '１', '２', '３', '４', '５', '６', '７', '８', '９'
          if curnum
            curnum *= 10
          else
            curnum = 0
          end
          curnum += c.tr('一二三四五六七八九１２３４５６７８９肆元朔正', '1234567891234567894111').to_i
        when '〇', '０', '0'
          curnum and curnum *= 10
        when '卄', '廿'
          ret3 += 20
          curnum = nil
        when '卅', '丗'
          ret3 += 30
          curnum = nil
        when '卌'
          ret3 += 40
          curnum = nil
        when '皕'
          ret3 += 200
          curnum = nil
        when '万', '億', '兆', '京', '垓'
          if curnum
            ret3 += curnum
            curnum = nil
          end
          ret3 = 1 if ret3.zero?
          ret4 += ret3 * 10**((%w[万 億 兆 京 垓].index(c) + 1) * 4)
          ret3 = 0
        when '十', '百', '千'
          curnum ||= 1
          ret3 += curnum * 10**(%w[十 百 千].index(c) + 1)
          curnum = nil
        end
      end
      if curnum
        ret3 += curnum
        curnum = nil
      end
      ret4 + ret3
    end

    def i_to_kan(num)
      ret = ''
      UNIT_SUFFIX2.each do |unit4, rank4|
        i4 = (num / rank4).to_i % 10_000
        next if i4.zero?

        if i4 == 1
          ret += "一#{unit4}"
          next
        end

        UNIT_SUFFIX1.each do |unit1, rank1|
          i1 = (i4 / rank1).to_i % 10
          next if i1.zero?

          if i1 == 1 && unit1 != ''
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

    class << self
      alias i2k i_to_kan
      alias k2i kan_to_i
      alias i2z i_to_zen
    end
  end
end
