require 'time'

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

  it 'preserves unsupported date range errors for recognized wareki dates' do
    date = '皇紀100年5月4日'

    expect { Date.parse(date) }.to raise_error(Wareki::UnsupportedDateRange)
    expect { Date._parse(date) }.to raise_error(Wareki::UnsupportedDateRange)
    expect { Time.parse(date) }.to raise_error(Wareki::UnsupportedDateRange)
  end

  it 'skips wareki parsing for obviously non-wareki strings' do
    expect(Date.parse('2020-01-01')).to eq Date.new(2020, 1, 1)
    expect(Date._parse('2020-01-01')).to eq({year: 2020, mon: 1, mday: 1})
    expect(Date.parse('2018/1/2(火)')).to eq Date.new(2018, 1, 2)
    expect(Date.parse('January 2, 2018')).to eq Date.new(2018, 1, 2)
    expect(Date.parse('弥生')).to eq Date.new(Date.today.year, 3, 1)
  end

  it 'sends ascii input directly to the original parsers' do
    allow(Wareki::Utils).to receive(:normalize_time).and_call_original

    expect(Date.parse('2025-07-01')).to eq Date._wareki_parse_orig('2025-07-01')
    expect(Date._parse('2025-07-01')).to eq Date._wareki__parse_orig('2025-07-01')
    expect(Wareki::Utils).not_to have_received(:normalize_time)
  end

  it 'preserves standard parsing for ascii dates and times' do
    ['2025-07-01', 'July 1, 2025', '2025-07-01 12:34:56'].each do |date|
      expect(Date.parse(date)).to eq Date._wareki_parse_orig(date)
      expect(Date._parse(date)).to eq Date._wareki__parse_orig(date)
    end
  end

  it 'keeps non-ascii dates and times on the wareki path' do
    expect(Date.parse('令和三年一月一日')).to eq Date.new(2021, 1, 1)
    expect(Date._parse('12時34分56秒')).to eq({hour: 12, min: 34, sec: 56})
    expect(Date.parse('弥生')).to eq Date.new(Date.today.year, 3, 1)
    expect(Date.parse('２０１８年１月２日')).to eq Date.new(2018, 1, 2)
  end

  it 'falls back after the wareki quick filter matches a non-wareki date' do
    date = '2018/1/2 (火曜日)'

    expect(Date.parse(date)).to eq Date.new(2018, 1, 2)
    expect(Date._parse(date)).to eq({year: 2018, mon: 1, mday: 2})
  end

  it 'raises on nonexistent wareki dates instead of falling back' do
    expect { Date.parse('天保1年2月30日') }.to raise_error(Wareki::InvalidDate)
    expect { Date.parse('明治5年12月3日') }.to raise_error(Wareki::InvalidDate)
    expect { Date.parse('平成12年13月3日') }.to raise_error(Wareki::InvalidDate)
    expect(Date._parse('平成12年2月30日')).to be_a(Hash)
  end

  it 'parses japanese time notations via _parse' do
    expect(Date._parse('平成元年5月4日 十二時三十四分五十六秒')).to eq(
      {year: 1989, mon: 5, mday: 4, hour: 12, min: 34, sec: 56}
    )
    expect(Date._parse('12時34分56秒')).to eq({hour: 12, min: 34, sec: 56})
    expect(Date._parse('午後三時半')).to eq({hour: 15, min: 30})
    expect(Date._parse('正午')).to eq({hour: 12, min: 0})
  end

  it 'makes Time.parse handle wareki dates with kansuji time' do
    expect(Time.parse('平成元年五月四日十二時三十四分五十六秒')).to eq Time.parse('1989-05-04 12:34:56')
    expect(Time.parse('平成元年5月4日 午後三時')).to eq Time.parse('1989-05-04 15:00')
    expect(Time.parse('令和三年一月一日 零時五分')).to eq Time.parse('2021-01-01 00:05')
    expect(Time.parse('㍻一〇年 肆月 晦日 正午')).to eq Time.parse('1998-04-30 12:00')
  end

  it 'rejects out-of-range kansuji times like their ascii equivalents' do
    expect { Time.parse('平成元年5月4日 二十五時') }.to raise_error(ArgumentError)
    expect { Time.parse('十二時七十分') }.to raise_error(ArgumentError)
    expect { Date.parse('12時34分') }.to raise_error(ArgumentError)
  end

  it 'still parses dates when a time notation follows' do
    expect(Date.parse('平成三十一年四月三十日 午後十一時五十九分')).to eq Date.new(2019, 4, 30)
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

  it 'supports wareki time directives on Time' do
    t = Time.new(2019, 5, 4, 13, 45, 6)
    expect(t.strftime('%JF %JTF')).to eq '令和元年五月四日 十三時四十五分六秒'
    expect(t.strftime('%JTf')).to eq '13時45分06秒'
    expect(t.strftime('%JTHk時%JTMk分')).to eq '十三時四十五分'
    expect(t.strftime('%F %H:%M:%S')).to eq '2019-05-04 13:45:06'
    expect(t.strftime('x%%JTF')).to eq 'x%JTF'
    expect(t.strftime('x%%JF')).to eq 'x%JF'
  end

  it 'adds Time#to_wareki_date' do
    t = Time.new(2019, 5, 4, 13, 45, 6)
    expect(t.to_wareki_date).to eq Wareki::Date.parse('令和元年五月四日')
  end

  it 'expands %JT but raises on %J date directives for pre-era times' do
    t = Time.new(100, 1, 2, 3, 4, 5)
    expect(t.strftime('%JTF')).to eq '三時四分五秒'
    expect { t.strftime('%JF') }.to raise_error(Wareki::UnsupportedDateRange)
  end

  it 'supports wareki time directives on DateTime' do
    dt = DateTime.new(2019, 5, 4, 13, 45, 6)
    expect(dt.strftime('%JF %JTF')).to eq '令和元年五月四日 十三時四十五分六秒'
    expect(dt.strftime('%JTf')).to eq '13時45分06秒'
    expect(dt.strftime).to eq dt._wareki_strftime_orig
  end

  it 'keeps %JT literal on Date' do
    expect(Date.new(2019, 5, 4).strftime('%JTF')).to eq '%JTF'
  end
end
