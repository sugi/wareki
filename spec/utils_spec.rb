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
end
