describe Wareki::Date do
  matchings = {
    # civil date => wareki date
    [1860, 4, 7]   => ["安政", 7, 3, 17, false],
    [2015, 8, 16]  => ["平成", 27, 8, 16, false],
    [645, 7, 17]   => ["大化", 1, 6, 19, false],
    [1145, 8, 12]  => ["久安", 1, 7, 22, false],
    [1145, 8, 11]  => ["天養", 2, 7, 21, false],
    [1683, 6, 28]  => ["天和", 3, 5, 4, true],
  }

  it "can be created with ydm args" do
    d = Wareki::Date.new("明治", 8, 2, 1)
    expect(d.era_name).to eq "明治"
    expect(d.era_year).to eq 8
    expect(d.year).to eq 1875

    d = Wareki::Date.new("皇紀", 1234, 3, 2)
    expect(d.era_name).to eq "皇紀"
    expect(d.era_year).to eq 1234
    expect(d.year).to eq 574
  end

  it "will be created by julian day number" do
    matchings.each do |civil, wareki|
      d = Date.civil(*civil)
      w = Wareki::Date.jd(d.jd)
      expect(w.era_name).to eq wareki[0]
      expect(w.era_year).to eq wareki[1]
      expect(w.month).to eq wareki[2]
      expect(w.day).to eq wareki[3]
      expect(w.leap_month?).to eq wareki[4]
    end
  end

  it "will be created by date instance" do
    matchings.each do |civil, wareki|
      d = Date.civil(*civil)
      w = Wareki::Date.date(d)
      expect(w.era_name).to eq wareki[0]
      expect(w.era_year).to eq wareki[1]
      expect(w.month).to eq wareki[2]
      expect(w.day).to eq wareki[3]
      expect(w.leap_month?).to eq wareki[4]
    end
  end

  it "can be compared with other instance" do
    d = Date.today
    wd = Wareki::Date.today
    expect(Wareki::Date.jd(d.jd) === wd).to be true
    expect(Wareki::Date.jd(d.jd) === d).to be true
    expect(Wareki::Date.jd(d.jd)).to eq wd
    expect(Wareki::Date.jd(d.jd)).not_to eq d
    expect(Wareki::Date.jd(d.jd)).to eql wd
    expect(Wareki::Date.jd(d.jd)).not_to eql d

    d2 = Date.today - 1
    expect(Wareki::Date.jd(d2.jd) === wd).to be false
    expect(Wareki::Date.jd(d2.jd) === d).to be false
    expect(Wareki::Date.jd(d2.jd)).not_to eq wd
    expect(Wareki::Date.jd(d2.jd)).not_to eq d
    expect(Wareki::Date.jd(d2.jd)).not_to eql wd
    expect(Wareki::Date.jd(d2.jd)).not_to eql d

    expect(Wareki::Date.jd(d2.jd) === 1).to be false
    expect(Wareki::Date.jd(d2.jd)).not_to eq 1
    expect(Wareki::Date.jd(d2.jd)).not_to eql 1
  end

  it "can be converted from date" do
    expect(Date.new(654, 2, 5, Date::GREGORIAN).to_wareki_date).to be_a(Wareki::Date)
    expect(Date.new(3000, 1, 1, Date::GREGORIAN).to_wareki_date).to be_a(Wareki::Date)
  end

  it "can be converted to julian day number" do
    matchings.each do |civil, wareki|
      d = Date.civil(*civil)
      w = Wareki::Date.new(*wareki)
      expect(w.jd).to eq d.jd
    end
  end

  it "can be calclated with number" do
    w = Wareki::Date.parse("平成7年11月10日")
    expect((w + 1).strftime("%Jf")).to eq "平成7年11月11日"
    expect((w - 1).strftime("%Jf")).to eq "平成7年11月9日"
    expect((w - 10).strftime("%Jf")).to eq "平成7年10月31日"
    expect((w + 21).strftime("%Jf")).to eq "平成7年12月1日"

    w = Wareki::Date.today
    expect(w + 1 === Date.today + 1).to eq true
    expect(w - 1 === Date.today - 1).to eq true
    expect(w - 94 === Date.today - 94).to eq true
    expect(w + 94 === Date.today + 94).to eq true
    expect(w + 94 === Date.today + 95).to eq false
    expect(w + 95 === Date.today + 94).to eq false
  end

  it "can not be calculated with ActiveSupport::Duration" do
    unless defined?(ActiveSupport::Duration)
      module ActiveSupport; class Duration;
        def self.days(v); new; end
      end; end; # Dummy...
    end
    expect {
      Wareki::Date.today + ActiveSupport::Duration.days(3)
    }.to raise_error(NotImplementedError)
    expect {
      Wareki::Date.today - ActiveSupport::Duration.days(3)
    }.to raise_error(NotImplementedError)
  end

  it "raises exception with unsupported date" do
    expect { Date.new(100, 1, 1, Date::GREGORIAN).to_wareki_date }.to raise_error(Wareki::UnsupportedDateRange)
    expect { Date.new(445, 1, 1, Date::GREGORIAN).to_wareki_date }.to raise_error(Wareki::UnsupportedDateRange)
    expect { Wareki::Date.parse("明治5年12月3日") }.to raise_error(ArgumentError)
    expect { Wareki::Date.parse("明治5年12月31日") }.to raise_error(ArgumentError)
    expect { Wareki::Date.parse("皇紀2532年12月5日") }.to raise_error(ArgumentError)
  end

  it "can parse date string" do
    d = Wareki::Date
    expect(d.parse("平成４年").to_date).to eq Wareki.parse_to_date("平成４年")

    expect(d.parse("平成27年１２月八日").to_date).to eq Date.new(2015, 12, 8)
    expect(d.parse("安政 ７年 ３月 １７日").to_date).to eq Date.new(1860, 4, 7)
    expect(d.parse("安政七年　\t 弥生卅日").to_date).to eq Date.new(1860, 4, 20)
    expect(d.parse("安政七年 弥生").to_date).to eq d.parse("安政7年3月1日").to_date
    expect(d.parse("元仁元年閏七月朔日").to_date).to eq Date.new(1224, 8, 17)
    expect(d.parse("元仁元年 うるう ７月１日").to_date).to eq Date.new(1224, 8, 17)
    expect(d.parse("元仁二年　元日").to_date).to eq Date.new(1225, 2, 9)
    expect(d.parse("寿永三年 五月 晦日").to_date).to eq Date.new(1184, 7, 9)
    expect(d.parse("慶應元年八月二十四日").to_date).to eq Date.new(1865, 10, 1, Date::JULIAN).new_start(Date::ITALY)
    expect(d.parse("平成元年元日").to_date).to eq Date.new(1989, 1, 1)
    expect(d.parse("平成12年十二月晦日").to_date).to eq Date.new(2000, 12, 31)

    expect(d.parse("10年5月3日").to_date).to eq Date.new(10, 5, 3)
    expect(d.parse("321年").to_date).to eq Date.new(321, 1, 1)
    expect(d.parse("2年12月31日").to_date).to eq Date.new(2, 12, 31)
    expect(d.parse("西暦10年5月3日").to_date).to eq Date.new(10, 5, 3)
    expect(d.parse("西暦321年").to_date).to eq Date.new(321, 1, 1)
    expect(d.parse("西暦2年12月31日").to_date).to eq Date.new(2, 12, 31)
    expect(d.parse("紀元前203年12月31日").to_date).to eq Date.new(-203, 12, 31)
    expect(d.parse("紀元前4年7月").to_date).to eq Date.new(-4, 7, 1)
    expect(d.parse("紀元前9876年4月2日").to_date).to eq Date.new(-9876, 4, 2)
    expect(d.parse("明治5年12月2日").to_date).to eq Date.new(1872, 12, 31)
    expect(d.parse("令和元年5月2日").to_date).to eq Date.new(2019, 5, 2)

    expect { d.parse("謎元号100年2月3日") }.to raise_error(ArgumentError)
    expect { d.parse("昭和2月3日") }.to raise_error(ArgumentError)
    expect { d.parse("昭和0年2月3日") }.to raise_error(ArgumentError)
    expect { d.parse("平成12年30月3日") }.to raise_error(ArgumentError)
    expect { d.parse("平成12年0月3日") }.to raise_error(ArgumentError)
    expect { d.parse("明治5年12月12日") }.to raise_error(ArgumentError)
  end

  it "can parse with white space" do
    d = Date
    exd = Date.new(1928, 3, 11)
    expect(d.parse(" 1928-3-11  ").to_date).to eq exd
    expect(d.parse("　1928 年 3 月　１１ 日  ").to_date).to eq exd
    expect(d.parse("\t\n　1 9 2 8 年 3 月　１１ 日  ").to_date).to eq exd
  end

  it "raise ArgumentError on parse empty string" do
    expect { Date.parse('') }.to raise_error(ArgumentError)
  end

  it "can parse date string without year" do
    today = Date.today
    d = Wareki::Date
    expect(d.parse("8月22日").to_date).to eq Date.new(today.year, 8, 22)
    expect(d.parse("2月25日").to_date).to eq Date.new(today.year, 2, 25)
    expect(d.parse("10月2日").to_date).to eq Date.new(today.year, 10, 2)
    expect(d.parse("3月8日").to_date).to eq Date.new(today.year, 3, 8)
    expect(d.parse("1月3日").to_date).to eq Date.new(today.year, 1, 3)
  end

  it "can be formatted in string" do
    d = Wareki::Date.new("天和", 3, 5, 4, true)
    expect(d.strftime).to eq "天和三年閏五月四日"
    expect(d.strftime("%JF")).to eq "天和三年閏五月四日"
    expect(d.strftime("%Jf")).to eq "天和3年5'月4日"
    expect(d.strftime("%Jo %JO %JOk")).to eq "1683 １６８３ 千六百八十三"
    expect(d.strftime("%Ji %JI %JIk")).to eq "2343 ２３４３ 二千三百四十三"
    expect(d.strftime("%Jd %JD %JDk")).to eq "4 ４ 四"
    expect(d.strftime("%Jm %JM %JMk")).to eq "5' 閏５ 閏五"
    expect(d.strftime("%Jy %JY %JYk")).to eq "天和3 天和３ 天和三"
    expect(d.strftime("皇紀で%Ji年%Jm月%Jd日")).to eq "皇紀で2343年5'月4日"
    expect(d.strftime("%JYk年　%JSK")).to eq "天和三年　皐月"
    expect(d.strftime("西暦だと%Y年%m月%d日")).to eq "西暦だと1683年06月28日"
    expect(d.strftime("未定義なやつはそのまま %JeK")).to eq "未定義なやつはそのまま %JeK"
    expect(d.strftime("特殊表記が無ければ普通に漢字: %Je%JGK年%JSK%JDK日")).to eq "特殊表記が無ければ普通に漢字: 天和三年皐月四日"
    expect(Wareki::Date.parse("寿永三年 五月 晦日").strftime("%Jd日")).to eq "30日"
    expect(Wareki::Date.parse("寿永2年 3月 晦日").strftime("%Jd日")).to eq "29日"
    expect(Wareki::Date.new("寿永", 2, 3, 29).strftime("%JDK日")).to eq "晦日"
    expect(Wareki::Date.new("寿永", 1, 2, 1).strftime("%JYK年%Jm月%JDK日")).to eq "寿永元年2月朔日"
    expect(Wareki::Date.new("寿永", 1, 1, 1).strftime("%JYK年%JM%JL月%JDK日")).to eq "寿永元年１月元日"
  end

  it "can handle last days of era" do
    expect(Date.parse("1989/1/7").strftime('%JF')).to eq "昭和六十四年一月七日"
    expect(Date.parse("1912/7/29").strftime('%JF')).to eq "明治四十五年七月二十九日"
    expect(Date.parse("1926/12/24").strftime('%JF')).to eq "大正十五年十二月二十四日"
  end

  it "can handle last days of year" do
    expect(Date.parse("1868/1/24").strftime('%JF')).to eq "慶応三年十二月三十日"
  end

  it "can parse short era name" do
    {'㍾' => '明治', '㍽' => '大正', '㍼' => '昭和', '㍻' => '平成'}.each do |short, canon|
      expect(Date.parse("#{short}十年３月9日").strftime('%Jf')).to eq "#{canon}10年3月9日"
    end
  end
end
