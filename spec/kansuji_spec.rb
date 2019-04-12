describe Wareki::Kansuji do
  u = Wareki::Utils

  it "converts kansuji to integer" do
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
    expect(u.k2i("肆陸")).to eq 46
    expect(u.k2i("弐仟柒佰玖什")).to eq 2790
    expect(u.k2i("捌萬貳拾")).to eq 80020
    expect(u.k2i("伍〇")).to eq 50
    expect(u.k2i("000023")).to eq 23
    expect(u.k2i("一千〇二十四")).to eq 1024
    expect(u.k2i("二百二十二万零三百零二")).to eq 2220302
    expect(u.k2i("六百〇八")).to eq 608
    expect(u.k2i("六百十")).to eq 610
    expect(u.k2i("千〇〇三")).to eq 1003
    expect(u.k2i("千〇十")).to eq 1010
  end

  it "can convert num to zenkaku" do
    expect(u.i2z(948230)).to eq "９４８２３０"
  end
end
