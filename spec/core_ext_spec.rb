describe Wareki::CoreExt do
  it "overrides strftime" do
    d = Date.new(2015, 8, 1)
    expect(d.strftime).to eq "2015-08-01"
    expect(d.strftime("%JF")).to eq "平成二十七年八月一日"
  end
end
