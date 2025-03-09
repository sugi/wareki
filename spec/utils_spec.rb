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

  it 'can find year with first and last day' do
    expect(u.find_year(2_275_903).year).to eq 1519
    expect(u.find_year(2_276_257).year).to eq 1519
    expect(u.find_year(2_293_061).year).to eq 1566
    expect(u.find_year(2_293_443).year).to eq 1566
  end
end
