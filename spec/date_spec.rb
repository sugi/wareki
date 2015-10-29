# coding: utf-8
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

  it "can be converted to julian day number" do
    matchings.each do |civil, wareki|
      d = Date.civil(*civil)
      w = Wareki::Date.new(*wareki)
      expect(w.jd).to eq d.jd
    end
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
  end

  it "can be formatted in string" do
    d = Wareki::Date.new("天和", 3, 5, 4, true)
    expect(d.strftime).to eq "天和三年閏五月四日"
    expect(d.strftime("%JF")).to eq "天和三年閏五月四日"
    expect(d.strftime("%Jf")).to eq "天和3年5'月4日"
    expect(d.strftime("%Jo %JO %JOk")).to eq "1683 １６８３ 千六百八十三"
    expect(d.strftime("%Ji %JI %JIk")).to eq "2343 ２３４３ 二千三百四十三"
    expect(d.strftime("%Jm %JM %JMk")).to eq "5' 閏５ 閏五"
    expect(d.strftime("%Jy %JY %JYk")).to eq "天和3 天和３ 天和三"
    expect(d.strftime("皇紀で%Ji年%Jm月%Jd日")).to eq "皇紀で2343年5'月4日"
    expect(d.strftime("%JYk年　%JSK")).to eq "天和三年　皐月"
    expect(d.strftime("西暦だと%Y年%m月%d日")).to eq "西暦だと1683年06月28日"
    expect(d.strftime("未定義なやつはそのまま %JeK")).to eq "未定義なやつはそのまま %JeK"
    expect(Wareki::Date.parse("寿永三年 五月 晦日").strftime("%Jd日")).to eq "30日"
    expect(Wareki::Date.parse("寿永2年 3月 晦日").strftime("%Jd日")).to eq "29日"
    expect(Wareki::Date.new("寿永", 2, 3, 29).strftime("%JDK日")).to eq "晦日"
    expect(Wareki::Date.new("寿永", 1, 2, 1).strftime("%JYK年%Jm月%JDK日")).to eq "寿永元年2月朔日"
    expect(Wareki::Date.new("寿永", 1, 1, 1).strftime("%JYK年%JM%JL月%JDK日")).to eq "寿永元年１月元日"
  end
end
