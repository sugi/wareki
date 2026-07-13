describe Wareki::Utils do
  u = described_class

  it 'returns proper era' do
    d1 = Date.new(1860, 4, 8)
    era = u.find_era(d1)
    expect(era.name).to eq '万延'

    d2 = Time.new(1860, 4, 7, 12, 1, 2)
    era = u.find_era(d2)
    expect(era.name).to eq '安政'
  end

  it 'returns nil on missing era' do
    e = u.find_era(Date.new(655, 12, 10))
    expect(e).to be_nil
    e = u.find_era(Date.new(686, 10, 2))
    expect(e).to be_nil
  end

  it 'can convert altanative month name to integer' do
    expect(u.alt_month_name_to_i('弥生')).to eq 3
    expect(u.alt_month_name_to_i('師走')).to eq 12
    expect(u.alt_month_name_to_i('水無月')).to eq 6
    expect(u.alt_month_name_to_i('ほげ')).to be false
  end

  it 'can find era by start and end day' do
    expect(u.find_era(2_447_534).name).to eq '昭和'
    expect(u.find_era(2_424_875).name).to eq '昭和'
    expect(u.find_era(2_403_357).name).to eq '明治'
    expect(u.find_era(2_419_613).name).to eq '明治'
  end

  it 'returns new era on overlap day' do
    expect(u.find_era(1_958_551).name).to eq '白雉'
    expect(u.find_era(2_256_978).name).to eq '応仁'
  end

  it 'prefers southern court eras on jd lookup (nanboku-cho)' do
    expect(u.find_era(Date.new(1337, 6, 1, Date::GREGORIAN)).name).to eq '延元'
    expect(u.find_era(Date.new(1340, 7, 26, Date::GREGORIAN)).name).to eq '興国'
    expect(u.find_era(Date.new(1350, 12, 21, Date::GREGORIAN)).name).to eq '正平'
    expect(u.find_era(Date.new(1332, 8, 17, Date::GREGORIAN)).name).to eq '元弘'
    expect(u.find_era(Date.new(1391, 1, 1, Date::GREGORIAN)).name).to eq '元中'
    expect(u.find_era(Date.new(1393, 5, 29, Date::GREGORIAN)).name).to eq '明徳'
  end

  it 'still accepts northern court era names on parse' do
    expect(Wareki::Date.parse('暦応3年1月1日').era_name).to eq '暦応'
    expect(Wareki::Date.parse('正慶2年1月1日').era_name).to eq '正慶'
  end

  it 'can find year with first and last day' do
    expect(u.find_year(2_275_903).year).to eq 1519
    expect(u.find_year(2_276_257).year).to eq 1519
    expect(u.find_year(2_293_061).year).to eq 1566
    expect(u.find_year(2_293_443).year).to eq 1566
  end

  it 'converts era year to civil year' do
    expect(u.era_year_to_civil('明治', 5)).to eq 1872
    expect(u.era_year_to_civil('㍾', 5)).to eq 1872
    expect(u.era_year_to_civil('皇紀', 2532)).to eq 1872
    expect(u.era_year_to_civil('神武天皇即位紀元', 2685)).to eq 2025
    expect(u.era_year_to_civil('', 2020)).to eq 2020
    expect(u.era_year_to_civil(nil, 2020)).to eq 2020
    expect(u.era_year_to_civil('西暦', 321)).to eq 321
    expect(u.era_year_to_civil('紀元前', 203)).to eq(-203)
    expect { u.era_year_to_civil('謎元号', 1) }.to raise_error(ArgumentError)
  end

  it 'converts civil year to era year' do
    expect(u.civil_to_era_year('明治', 1872)).to eq 5
    expect(u.civil_to_era_year('皇紀', 1872)).to eq 2532
    expect(u.civil_to_era_year('紀元前', -203)).to eq 203
    expect(u.civil_to_era_year('', 2020)).to eq 2020
  end

  it 'returns last day of month by era' do
    expect(u.last_day_of_era_month('明治', 1872, 10, false)).to eq 30
    expect(u.last_day_of_era_month('皇紀', 1872, 10, false)).to eq 30
    expect(u.last_day_of_era_month('', 2000, 2, false)).to eq 29
    expect(u.last_day_of_era_month('紀元前', -1, 12, false)).to eq 31
    expect(u.last_day_of_era_month('西暦', 300, 5, false)).to eq 31
    expect(u.last_day_of_era_month('令和', 2021, 2, false)).to eq 28
  end

  it 'returns nil for jd before the year table' do
    expect(u.find_year(1_883_617)).to be_nil
    expect(u.find_year(1_883_618).year).to eq 445
  end

  it 'keeps ERA_JD_LOOKUP sorted, disjoint and frozen' do
    lookup = Wareki::ERA_JD_LOOKUP
    expect(lookup).to be_frozen
    expect(lookup.all?(&:frozen?)).to be true
    expect(lookup.each_cons(2).all? { |a, b| a.end < b.start && a.end < b.end }).to be true
    expect(lookup.map(&:name) & Wareki::NORTH_COURT_ERA_NAMES).to be_empty
  end

  it 'i_to_kan still works as deprecated api' do
    result = nil
    expect { result = u.i_to_kan(5) }.to output(/DEPRECATED/).to_stderr
    expect(result).to eq '五'
  end

  it 'freezes era definitions' do
    expect(Wareki::ERA_DEFS).to all(be_frozen)
    expect(Wareki::ERA_NORTH_DEFS).to all(be_frozen)
    expect(Wareki::ERA_BY_NAME['皇紀']).to be_frozen
    expect(Wareki::ERA_BY_NAME['西暦']).to be_frozen
    expect(u.find_era(Date.new(2019, 5, 1))).to be_frozen
  end
end
