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
    u = Wareki::Date
    expect(u.parse("平成27年１２月八日").to_date).to eq Date.new(2015, 12, 8)
    expect(u.parse("安政 ７年 ３月 １７日").to_date).to eq Date.new(1860, 4, 7)
    expect(u.parse("安政七年　\t 弥生卅日").to_date).to eq Date.new(1860, 4, 20)
    expect(u.parse("安政七年 弥生").to_date).to eq u.parse("安政7年3月1日").to_date
    expect(u.parse("元仁元年閏七月朔日").to_date).to eq Date.new(1224, 8, 17)
    expect(u.parse("元仁元年 うるう ７月１日").to_date).to eq Date.new(1224, 8, 17)
    expect(u.parse("元仁二年　元日").to_date).to eq Date.new(1225, 2, 9)
    expect(u.parse("寿永三年 五月 晦日").to_date).to eq Date.new(1184, 7, 9)
  end

  it "can be formatted in string" do
    d = Wareki::Date.new("天和", 3, 5, 4, true)
    expect(d.strftime).to eq "天和三年閏五月四日"
    expect(d.strftime("%JF")).to eq "天和三年閏五月四日"
    expect(d.strftime("%Jf")).to eq "天和3年5'月4日"
    expect(d.strftime("皇紀で%Ji年%Jm月%Jd日")).to eq "皇紀で2343年5'月4日"
    expect(d.strftime("%JYk年　%JSK")).to eq "天和三年　皐月"
    expect(d.strftime("西暦だと%Y年%m月%d日")).to eq "西暦だと1683年06月28日"
    expect(d.strftime("未定義なやつはそのまま %JeK")).to eq "未定義なやつはそのまま %JeK"
    expect(Wareki::Date.parse("寿永三年 五月 晦日").strftime("%Jd日")).to eq "30日"
    expect(Wareki::Date.parse("寿永2年 3月 晦日").strftime("%Jd日")).to eq "29日"
    expect(Wareki::Date.new("寿永", 2, 3, 29).strftime("%JDK日")).to eq "晦日"
    expect(Wareki::Date.new("寿永", 1, 2, 1).strftime("%JYK年%Jm月%JDK日")).to eq "寿永元年2月朔日"
  end
end
