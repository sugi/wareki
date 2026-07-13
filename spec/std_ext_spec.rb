describe Wareki::StdExt do
  it 'overrides strftime' do
    d = Date.new(2015, 8, 1)
    expect(d.strftime).to eq '2015-08-01'
    expect(d.strftime('%JF')).to eq '平成二十七年八月一日'
  end

  it 'overrides parse' do
    expect(Date.parse).to eq Date._wareki_parse_orig
    expect(Date.parse('平成 二十七年 八月 朔日')).to eq Date.new(2015, 8, 1)
    expect(Date.parse('2015-08-01')).to eq Date.new(2015, 8, 1)
    expect do
      Date.parse('completely invalid date')
    end.to raise_error(ArgumentError)
  end

  it 'overrides _parse' do
    expect(Date._parse('平成元年5月4日')).to eq({year: 1989, mon: 5, mday: 4})
    expect(Date._parse('平成元年5月4日12:34:56')).to eq({year: 1989, mon: 5, mday: 4, hour: 12, min: 34, sec: 56})
    expect(Date._parse('completely invalid date')).to eq({})
  end

  it 'have Date::JAPAN' do
    expect(Date::JAPAN).to eq Wareki::GREGORIAN_START
  end

  it 'does not misfire wareki conversion on escaped or invalid %J' do
    d = Date.new(100, 1, 1, Date::GREGORIAN)
    expect(d.strftime('x%%JF')).to eq 'x%JF'
    expect(d.strftime('x%Jz')).to eq 'x%Jz'
    expect { d.strftime('%JF') }.to raise_error(Wareki::UnsupportedDateRange)
  end

  it 'supports wareki directives on DateTime' do
    dt = DateTime.new(2019, 5, 4, 13, 45, 6)
    expect(dt.strftime('%JF')).to eq '令和元年五月四日'
    expect(dt.strftime('%JF %H:%M:%S')).to eq '令和元年五月四日 13:45:06'
    expect(dt.strftime('%F')).to eq '2019-05-04'
    expect(dt.strftime).to eq dt._wareki_strftime_orig
  end
end
