# coding: utf-8
describe Wareki::Utils do
  u = Wareki::Utils

  it "returns proper era" do
    d1 = Date.new(1860, 4, 8)
    era = u.find_era(d1)
    expect(era.name).to eq "万延"

    d2 = Date.new(1860, 4, 7)
    era = u.find_era(d2)
    expect(era.name).to eq "安政"
  end

  it "returns nil on missing era" do
    e = u.find_era(Date.new(655, 12, 10))
    expect(e).to be_nil
    e = u.find_era(Date.new(686, 10, 2))
    expect(e).to be_nil
  end

  it "converts kansuji to integer" do
    expect(u.kan_to_i("千二百三十四")).to eq 1234
    expect(u.kan_to_i("百卄")).to eq 120
    expect(u.kan_to_i("一二三四")).to eq 1234
    expect(u.kan_to_i("千皕卅肆")).to eq 1234
    expect(u.kan_to_i("一〇〇〇五")).to eq 10005
    expect(u.kan_to_i("〇")).to eq 0
    expect(u.kan_to_i("零")).to eq 0
    expect(u.kan_to_i("元")).to eq 1
    expect(u.kan_to_i("五万廿")).to eq 50020
    expect(u.kan_to_i("百七十八万二")).to eq 1780002
    expect(u.kan_to_i("九億６千万卌一")).to eq 960000041
  end

  it "can convert altanative month name to integer" do
    expect(u.alt_month_name_to_i("弥生")).to eq 3
    expect(u.alt_month_name_to_i("師走")).to eq 12
    expect(u.alt_month_name_to_i("水無月")).to eq 6
    expect(u.alt_month_name_to_i("ほげ")).to eq false
  end

  it "can convert num to zenkaku" do
    expect(u.i_to_zen(101239)).to eq "１０１２３９"
  end

  it "can convert num to kansuji" do
    expect(u.i_to_kan(1234)).to eq "千二百三十四"
    expect(u.i_to_kan(10003)).to eq "一万三"
    expect(u.i_to_kan(10_010_003)).to eq "千一万三"
    expect(u.i_to_kan(100_000_003)).to eq "一億三"
    expect(u.i_to_kan(200_000_000_056)).to eq "二千億五十六"
    expect(u.i_to_kan(9_030_000_001_008)).to eq "九兆三百億千八"
  end

  it "can find era by start and end day" do
    expect(u.find_era(2447534).name).to eq "昭和"
    expect(u.find_era(2424875).name).to eq "昭和"
    expect(u.find_era(2403357).name).to eq "明治"
    expect(u.find_era(2419613).name).to eq "明治"
  end

  it "returns new era on overlap day" do
    expect(u.find_era(1958551).name).to eq "白雉"
    expect(u.find_era(2256978).name).to eq "応仁"
  end

  it "can find year with first and last day" do
    expect(u.find_year(2275903).year).to eq 1519
    expect(u.find_year(2276257).year).to eq 1519
    expect(u.find_year(2293061).year).to eq 1566
    expect(u.find_year(2293443).year).to eq 1566
  end
end
