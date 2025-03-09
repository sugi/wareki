describe Wareki do
  it 'fallbacks to original Date.parse with invalid ja date by parse_to_date()' do
    d = described_class.parse_to_date '2018-01-02'
    expect(d).to be_a(Date)
    expect(d.year).to eq 2018
    expect(d.month).to eq 1
    expect(d.day).to eq 2

    expect(described_class.parse_to_date('10')).to be_a(Date) # Wierd ruby default behaviour...
  end

  it 'has a version number' do
    expect(Wareki::VERSION).not_to be_nil
  end
end
