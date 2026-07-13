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

  it 'prefers northern court eras on jd lookup (nanboku-cho)' do
    expect(u.find_era(Date.new(1332, 8, 17, Date::GREGORIAN)).name).to eq '正慶'
    expect(u.find_era(Date.new(1340, 7, 26, Date::GREGORIAN)).name).to eq '暦応'
    expect(u.find_era(Date.new(1350, 12, 21, Date::GREGORIAN)).name).to eq '観応'
    expect(u.find_era(Date.new(1391, 1, 1, Date::GREGORIAN)).name).to eq '明徳'
    expect(u.find_era(Date.new(1393, 5, 29, Date::GREGORIAN)).name).to eq '明徳'
    # 北朝側の改元(暦応)前は北朝に固有の元号がなく、南朝の元号が返る
    expect(u.find_era(Date.new(1337, 6, 1, Date::GREGORIAN)).name).to eq '延元'
  end

  it 'still accepts northern court era names on parse' do
    expect(Wareki::Date.parse('暦応3年1月1日').era_name).to eq '暦応'
    expect(Wareki::Date.parse('正慶2年1月1日').era_name).to eq '正慶'
  end

  it 'still accepts southern court era names on parse' do
    expect(Wareki::Date.parse('正平7年1月1日').era_name).to eq '正平'
    expect(Wareki::Date.parse('元中8年1月1日').era_name).to eq '元中'
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

  it 'normalizes japanese time notations' do
    expect(u.normalize_time('十二時三十四分五十六秒')).to eq '12:34:56'
    expect(u.normalize_time('１２時３４分')).to eq '12:34'
    expect(u.normalize_time('12時34分56秒')).to eq '12:34:56'
    expect(u.normalize_time('三時半')).to eq '03:30'
    expect(u.normalize_time('午後三時')).to eq '15:00'
    expect(u.normalize_time('午後三時半')).to eq '15:30'
    expect(u.normalize_time('午前十時 五分')).to eq '10:05'
    expect(u.normalize_time('午前十時　五分')).to eq '10:05'
    expect(u.normalize_time('午後 十一時 五十九分 五十九秒')).to eq '23:59:59'
    expect(u.normalize_time('正午')).to eq '12:00'
    expect(u.normalize_time('零時')).to eq '00:00'
    expect(u.normalize_time('十二時')).to eq '12:00'
    expect(u.normalize_time('午前十二時')).to eq '12:00'
    expect(u.normalize_time('午後十二時')).to eq '12:00'
    expect(u.normalize_time('平成元年五月四日十二時三十四分')).to eq '平成元年五月四日12:34'
  end

  it 'uses cached simple kansuji for values from 0 through 99' do
    expected = {
      0 => '零', 1 => '一', 9 => '九', 10 => '十',
      31 => '三十一', 59 => '五十九', 60 => '六十', 99 => '九十九',
    }

    expect(described_class::SIMPLE_KANSUJI_CACHE).to be_frozen
    expect(described_class::SIMPLE_KANSUJI_CACHE).to all(be_frozen)
    allow(YaKansuji).to receive(:to_kan).and_call_original
    expected.each do |num, kansuji|
      expect(u.to_simple_kan(num)).to eq kansuji
    end
    expect(YaKansuji).not_to have_received(:to_kan)

    result = u.to_simple_kan(31)
    expect(result).not_to be_frozen
    result << '日'
    expect(result).to eq '三十一日'
    expect(described_class::SIMPLE_KANSUJI_CACHE[31]).to eq '三十一'
  end

  it 'delegates simple kansuji outside the cache range' do
    expected_hundred = YaKansuji.to_kan(100, :simple)
    expected_negative = YaKansuji.to_kan(-1, :simple)
    allow(YaKansuji).to receive(:to_kan).and_call_original

    expect(u.to_simple_kan(100)).to eq expected_hundred
    expect(u.to_simple_kan(-1)).to eq expected_negative
    expect(YaKansuji).to have_received(:to_kan).with(100, :simple).once
    expect(YaKansuji).to have_received(:to_kan).with(-1, :simple).once
  end

  it 'transliterates out-of-range times as-is' do
    expect(u.normalize_time('二十五時')).to eq '25:00'
    expect(u.normalize_time('十二時七十分')).to eq '12:70'
  end

  it 'replaces only the first time notation' do
    expect(u.normalize_time('三時と五時')).to eq '03:00と五時'
  end

  it 'keeps strings without time notation unchanged' do
    s = '平成元年5月4日'
    expect(u.normalize_time(s)).to equal s
    expect(u.normalize_time('明治時代')).to eq '明治時代'
    expect(u.normalize_time('元年時')).to eq '元年時'
  end

  it 'expands %JT time format directives' do
    t = Time.new(2015, 8, 1, 12, 34, 56)
    expect(u.expand_time_format('%JTf', t)).to eq '12時34分56秒'
    expect(u.expand_time_format('%JTF', t)).to eq '十二時三十四分五十六秒'
    expect(u.expand_time_format('%JTH', t)).to eq '１２'
    expect(u.expand_time_format('%JTHk', t)).to eq '十二'
    expect(u.expand_time_format('%JTM', t)).to eq '３４'
    expect(u.expand_time_format('%JTMk', t)).to eq '三十四'
    expect(u.expand_time_format('%JTS', t)).to eq '５６'
    expect(u.expand_time_format('%JTSk', t)).to eq '五十六'
    expect(u.expand_time_format('%JTHk時%JTMk分', t)).to eq '十二時三十四分'
  end

  it 'pads %JTf like %Jf and honors padding flags' do
    t = Time.new(2015, 8, 1, 3, 4, 5)
    expect(u.expand_time_format('%JTf', t)).to eq '03時04分05秒'
    expect(u.expand_time_format('%J-Tf', t)).to eq '3時4分5秒'
  end

  it 'always emits all three components for composite time directives' do
    t = Time.new(2015, 8, 1, 0, 0, 0)
    expect(u.expand_time_format('%JTF', t)).to eq '零時零分零秒'
    expect(u.expand_time_format('%JTf', t)).to eq '00時00分00秒'
  end

  it 'leaves escaped or unknown %JT sequences alone' do
    t = Time.new(2015, 8, 1, 12, 34, 56)
    expect(u.expand_time_format('x%%JTF %JTHk', t)).to eq 'x%%JTF 十二'
    expect(u.expand_time_format('%JTz', t)).to eq '%JTz'
    expect(u.expand_time_format('%H:%M:%S', t)).to eq '%H:%M:%S'
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

  it 'deep freezes calendar year definitions' do
    year_def = Wareki::YEAR_DEFS.first

    expect(Wareki::YEAR_DEFS).to be_frozen
    expect(Wareki::YEAR_DEFS).to all(be_frozen)
    expect(Wareki::YEAR_DEFS.map(&:month_starts)).to all(be_frozen)
    expect(Wareki::YEAR_DEFS.map(&:month_days)).to all(be_frozen)
    expect(Wareki::YEAR_BY_NUM[year_def.year]).to equal year_def
    expect(Wareki::YEAR_BY_NUM[year_def.year]).to be_frozen

    expect { year_def.month_starts << year_def.start }.to raise_error(RuntimeError)
    expect { year_def.month_days << 30 }.to raise_error(RuntimeError)
    expect { year_def.year = 0 }.to raise_error(RuntimeError)
  end

  it 'keeps historical lunisolar conversion working with frozen definitions' do
    civil_date = Date.new(1683, 6, 28, Date::GREGORIAN)
    wareki_date = Wareki::Date.date(civil_date)

    expect([wareki_date.era_name, wareki_date.era_year, wareki_date.month,
            wareki_date.day, wareki_date.leap_month?]).to eq ['天和', 3, 5, 4, true]
    expect(Wareki::Date.new('天和', 3, 5, 4, true).to_date(Date::GREGORIAN)).to eq civil_date
  end
end
