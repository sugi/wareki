# coding: utf-8
describe Wareki::Kansuji do
  u = Wareki::Kansuji

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
    expect(u.kan_to_i("肆陸")).to eq 46
    expect(u.kan_to_i("弐仟柒佰玖什")).to eq 2790
    expect(u.kan_to_i("捌萬貳拾")).to eq 80020
    expect(u.kan_to_i("伍〇")).to eq 50
    expect(u.kan_to_i("000023")).to eq 23
  end

  it "converts kansuji to integer with k2i" do
    expect(u.k2i("千二百三十四")).to eq 1234
    expect(u.k2i("百卄")).to eq 120
    expect(u.k2i("一二三四")).to eq 1234
    expect(u.k2i("千皕卅肆")).to eq 1234
    expect(u.k2i("一〇〇〇五")).to eq 10005
    expect(u.k2i("〇")).to eq 0
    expect(u.k2i("零")).to eq 0
    expect(u.k2i("元")).to eq 1
    expect(u.k2i("五万廿")).to eq 50020
    expect(u.k2i("百七十八万二")).to eq 1780002
    expect(u.k2i("九億６千万卌一")).to eq 960000041
  end

  it "can convert num to zenkaku" do
    expect(u.i_to_zen(101239)).to eq "１０１２３９"
    expect(u.i2z(948230)).to eq "９４８２３０"
  end

  it "can convert num to kansuji" do
    expect(u.i_to_kan(1234)).to eq "千二百三十四"
    expect(u.i_to_kan(10003)).to eq "一万三"
    expect(u.i_to_kan(10_010_003)).to eq "千一万三"
    expect(u.i_to_kan(100_000_003)).to eq "一億三"
    expect(u.i_to_kan(200_000_000_056)).to eq "二千億五十六"
    expect(u.i_to_kan(9_030_000_001_008)).to eq "九兆三百億千八"
  end

  it "can convert num to kansuji with i2k" do
    expect(u.i2k(1234)).to eq "千二百三十四"
    expect(u.i2k(10003)).to eq "一万三"
    expect(u.i2k(10_010_003)).to eq "千一万三"
    expect(u.i2k(100_000_003)).to eq "一億三"
    expect(u.i2k(200_000_000_056)).to eq "二千億五十六"
    expect(u.i2k(9_030_000_001_008)).to eq "九兆三百億千八"
  end
end
