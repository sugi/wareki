# frozen_string_literal: true

require 'spec_helper'
require 'wareki/calendar'

describe Wareki::Calendar do
  let(:c) { described_class }

  it 'defines table range constants' do
    expect(c::YEAR_MIN).to eq 445
    expect(c::YEAR_MAX).to eq 1872
    expect(c::JD_MIN).to eq 1_883_618
    expect(c::JD_MAX).to eq 2_405_159
    expect(c::LAST_MONTH_DAYS).to eq 2
    expect(c::PACKED).to be_frozen
    expect(c::PACKED.size).to eq 1428
  end

  it 'answers year coverage' do
    expect(c.covers_year?(444)).to be false
    expect(c.covers_year?(445)).to be true
    expect(c.covers_year?(1872)).to be true
    expect(c.covers_year?(1873)).to be false
  end

  it 'returns nil for out-of-range input' do
    expect(c.find_date_ary(c::JD_MIN - 1)).to be_nil
    expect(c.find_date_ary(c::JD_MAX + 1)).to be_nil
    expect(c.to_jd(444, 1, 1, false)).to be_nil
    expect(c.to_jd(1873, 1, 1, false)).to be_nil
    expect(c.last_day_of_month(444, 1, false)).to be_nil
    expect(c.leap_month(1873)).to be_nil
  end

  it 'converts table boundary days' do
    expect(c.find_date_ary(1_883_618)).to eq [445, 1, 1, false]
    expect(c.find_date_ary(2_405_159)).to eq [1872, 12, 2, false]
    expect(c.to_jd(445, 1, 1, false)).to eq 1_883_618
    expect(c.to_jd(1872, 12, 2, false)).to eq 2_405_159
  end

  it 'finds years at year boundary days' do
    expect(c.find_date_ary(2_275_903)[0]).to eq 1519
    expect(c.find_date_ary(2_276_257)[0]).to eq 1519
    expect(c.find_date_ary(2_293_061)[0]).to eq 1566
    expect(c.find_date_ary(2_293_443)[0]).to eq 1566
  end

  it 'handles leap months' do
    expect(c.leap_month(1683)).to eq 5
    expect(c.leap_month(1000)).to be_nil
    # 天和3年閏5月4日 = 1683-06-28 (Gregorian) = JD 2335942
    expect(c.to_jd(1683, 5, 4, true)).to eq 2_335_942
    expect(c.find_date_ary(2_335_942)).to eq [1683, 5, 4, true]
    expect(c.to_jd(1683, 5, 4, false)).to be < 2_335_942
  end

  it 'returns 2 days for the truncated last month (Meiji 5, Dec)' do
    expect(c.last_day_of_month(1872, 12, false)).to eq 2
  end

  it 'roundtrips every day in the table' do
    mismatch = (c::JD_MIN..c::JD_MAX).reject do |jd|
      year, month, day, is_leap = c.find_date_ary(jd)
      c.to_jd(year, month, day, is_leap) == jd
    end
    expect(mismatch).to eq []
  end
end
