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
end
