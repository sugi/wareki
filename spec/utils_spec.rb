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
    e = u.find_era(Date.new(686, 10, 1))
    expect(e).to be_nil
  end

  it "converts kansuji to integer" do
    expect(u.kan_to_i("千二百三十四")).to eq 1234
    expect(u.kan_to_i("一二三四")).to eq 1234
    expect(u.kan_to_i("千皕卅肆")).to eq 1234
    expect(u.kan_to_i("一〇〇〇五")).to eq 10005
    expect(u.kan_to_i("〇")).to eq 0
    expect(u.kan_to_i("零")).to eq 0
    expect(u.kan_to_i("元")).to eq 1
    expect(u.kan_to_i("五万廿")).to eq 50020
  end

  it "can convert altanative month name to integer" do
    expect(u.alt_month_name_to_i("弥生")).to eq 3
    expect(u.alt_month_name_to_i("師走")).to eq 12
    expect(u.alt_month_name_to_i("水無月")).to eq 6
  end

end
