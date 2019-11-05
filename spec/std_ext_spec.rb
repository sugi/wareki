describe Wareki::StdExt do
  it "overrides strftime" do
    d = Date.new(2015, 8, 1)
    expect(d.strftime).to eq "2015-08-01"
    expect(d.strftime("%JF")).to eq "平成二十七年八月一日"
  end

  it "overrides parse" do
    expect(Date.parse("平成 二十七年 八月 朔日")).to eq Date.new(2015, 8, 1)
    expect(Date.parse("2015-08-01")).to eq Date.new(2015, 8, 1)
    expect {
      Date.parse("completely invalid date")
    }.to raise_error(ArgumentError)
  end

  it "overrides _parse" do
    expect(Date._parse("平成元年5月4日")).to eq({ year: 1989, mon: 5, mday: 4 })
    expect(Date._parse("平成元年5月4日12:34:56")).to eq({ year: 1989, mon: 5, mday: 4, hour: 12, min: 34, sec: 56 })
  end

  it "have Date::JAPAN" do
    expect(Date::JAPAN).to eq Wareki::GREGORIAN_START
  end
end
