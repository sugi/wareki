# Time.parse / Time#strftime 漢数字時刻サポート Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Time.parse が漢数字・全角数字の時刻表記を解釈し、Time#strftime / DateTime#strftime が %JT 時刻フォーマット指示子を展開できるようにする。

**Architecture:** パース側は日本語時刻表記を ASCII の `HH:MM(:SS)` へ「翻字」してから Ruby 標準パーサへ委ねる純粋な文字列正規化で、既存の `Date._parse` / `Date.parse` フックの先頭に組み込む(Time.parse は内部で `Date._parse` を呼ぶため Time クラスのパースパッチは不要)。フォーマット側は既存の `Wareki::Date#expand_wareki_format`(%J 日付トークン)を共用し、%JT 時刻トークン展開を `Wareki::Utils` に新設して Time / DateTime の strftime パッチから使う。

**Tech Stack:** Ruby (gem wareki)、ya_kansuji(漢数字変換、既存依存)、RSpec、RuboCop。

**Design spec:** `docs/superpowers/specs/2026-07-13-time-kansuji-support-design.md`(承認済み。判断に迷ったらこちらが正)

## Global Constraints

- 新規ファイル・新規 gem 依存・新規 require を追加しない(`require 'time'` はテストコードのみ可)
- gemspec は `required_ruby_version >= 2.0.0`、CI は ruby 2.7〜3.4 + head。保守的な構文を使う(既存コードの範囲内の書き方に合わせる)
- 全ファイル `# frozen_string_literal: true` 済み。Layout/LineLength Max 130
- RuboCop は master 時点で 5 offenses が既存(Style/OneClassPerFile ×2 in std_ext.rb、RSpec/LeakyLocalVariable ×3 in spec)。CI は rubocop を回さない(ローカル lint のみ)。**「新規 offense を増やさない」が基準**で、例外は2つだけ: Task 3 で Metrics/ModuleLength の Max を引き上げる(.rubocop.yml 修正、手順に含む)、Task 4 の `class Time` 追加で Style/OneClassPerFile が1件増える(既存カテゴリで不可避、許容)
- コミットメッセージは英語
- テスト実行はリポジトリルートで `bundle exec rspec`(gem が無ければ最初に `bundle install`)
- インラインで `ruby -e '日本語...'` を実行する場合は `LANG=C.UTF-8 LC_ALL=C.UTF-8` を付ける(シェルが US-ASCII のため)
- 既存テストを壊さない。挙動変更が許されるのは spec の「互換性への影響」に列挙された3点のみ

---

### Task 1: TIME_REGEX 定数と Utils.normalize_time

**Files:**
- Modify: `lib/wareki/common.rb`(`PARSE_QUICK_FILTER` 定義の直後、`class UnsupportedDateRange` の前)
- Modify: `lib/wareki/utils.rb`(`k2i` メソッドの直後)
- Test: `spec/utils_spec.rb`

**Interfaces:**
- Consumes: `Wareki::NUM_CHARS`, `Wareki::Utils.k2i`(既存)
- Produces: `Wareki::TIME_REGEX`(named captures: noon/ampm/hour/half/min/sec)、`Wareki::TIME_PARSE_QUICK_FILTER`、`Wareki::Utils.normalize_time(str) -> String`(Task 2 が使用。時刻表記なしなら入力オブジェクトをそのまま返す)

- [ ] **Step 1: Write the failing tests**

`spec/utils_spec.rb` の `it 'i_to_kan still works as deprecated api' do ... end` ブロックの直前に追加:

```ruby
  it 'normalizes japanese time notations' do
    expect(u.normalize_time('十二時三十四分五十六秒')).to eq '12:34:56'
    expect(u.normalize_time('１２時３４分')).to eq '12:34'
    expect(u.normalize_time('12時34分56秒')).to eq '12:34:56'
    expect(u.normalize_time('三時半')).to eq '03:30'
    expect(u.normalize_time('午後三時')).to eq '15:00'
    expect(u.normalize_time('午後三時半')).to eq '15:30'
    expect(u.normalize_time('午前十時 五分')).to eq '10:05'
    expect(u.normalize_time('午後 十一時 五十九分 五十九秒')).to eq '23:59:59'
    expect(u.normalize_time('正午')).to eq '12:00'
    expect(u.normalize_time('零時')).to eq '00:00'
    expect(u.normalize_time('十二時')).to eq '12:00'
    expect(u.normalize_time('午前十二時')).to eq '12:00'
    expect(u.normalize_time('午後十二時')).to eq '12:00'
    expect(u.normalize_time('平成元年五月四日十二時三十四分')).to eq '平成元年五月四日12:34'
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/utils_spec.rb`
Expected: FAIL, `NoMethodError: undefined method 'normalize_time'`(新規4例とも)

- [ ] **Step 3: Implement TIME_REGEX / TIME_PARSE_QUICK_FILTER**

`lib/wareki/common.rb` の `PARSE_QUICK_FILTER = /[年月日]|元旦|弥生|師走/.freeze` の直後に追加:

```ruby
  TIME_REGEX = %r{
    (?<noon>正午) |
    (?:(?<ampm>午前|午後)[[:space:]]*)?
    (?<hour>[#{NUM_CHARS}]+)[[:space:]]*時
    (?:[[:space:]]*
      (?:(?<half>半) |
         (?<min>[#{NUM_CHARS}]+)[[:space:]]*分
         (?:[[:space:]]*(?<sec>[#{NUM_CHARS}]+)[[:space:]]*秒)?))?
  }x.freeze
  # TIME_REGEX が非空マッチしうるのは「時」か「正午」を含む文字列のみ
  TIME_PARSE_QUICK_FILTER = /時|正午/.freeze
```

- [ ] **Step 4: Implement Utils.normalize_time**

`lib/wareki/utils.rb` の `k2i` メソッド定義(`def k2i ... end`)の直後に追加:

```ruby
    # 日本語の時刻表記 (漢数字・全角数字の時分秒、午前/午後、半、正午) を
    # 等価な "HH:MM(:SS)" 表記へ置換する。値の範囲チェックは行わず、
    # 妥当性判断は Ruby 標準パーサに委ねる (二十五時 -> "25:00")。
    def normalize_time(str)
      str.to_s =~ TIME_PARSE_QUICK_FILTER or return str
      str.to_s.sub(TIME_REGEX) { _time_match_to_s(Regexp.last_match) }
    end

    def _time_match_to_s(match)
      return '12:00' if match[:noon]

      hour = k2i(match[:hour])
      hour += 12 if match[:ampm] == '午後' && hour < 12
      min = 0
      min = 30 if match[:half]
      min = k2i(match[:min]) if match[:min]
      return Kernel.format('%02d:%02d', hour, min) unless match[:sec]

      Kernel.format('%02d:%02d:%02d', hour, min, k2i(match[:sec]))
    end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/utils_spec.rb`
Expected: PASS(全例)

- [ ] **Step 6: Run full suite and rubocop**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: rspec 全て PASS / rubocop はベースラインの 5 offenses のみ(新規なし)

- [ ] **Step 7: Commit**

```bash
git add lib/wareki/common.rb lib/wareki/utils.rb spec/utils_spec.rb
git commit -m "Add Utils.normalize_time to transliterate Japanese time notations"
```

---

### Task 2: Date._parse / Date.parse への時刻正規化の組み込み

**Files:**
- Modify: `lib/wareki/std_ext.rb`(`class << self` 内の `parse` と `_parse`)
- Test: `spec/std_ext_spec.rb`

**Interfaces:**
- Consumes: `Wareki::Utils.normalize_time(str)`(Task 1)
- Produces: パッチ済み `Date._parse` / `Date.parse` が漢数字時刻を解釈(`Time.parse` は stdlib 実装が `Date._parse` を呼ぶため自動的に対応される)

- [ ] **Step 1: Write the failing tests**

`spec/std_ext_spec.rb` の先頭行(`describe Wareki::StdExt do` の前)に追加:

```ruby
require 'time'
```

`it 'have Date::JAPAN' do ... end` ブロックの直前に追加:

```ruby
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/std_ext_spec.rb`
Expected: FAIL。目安: `Date._parse('12時34分56秒')` が `{mday: 12}` を返す、
`Time.parse('平成元年五月四日十二時三十四分五十六秒')` が 00:00:00 になる、
`Date.parse('12時34分')` が例外を上げず日付を返す、など

- [ ] **Step 3: Implement normalization in parse hooks**

`lib/wareki/std_ext.rb` の `class << self ... end` ブロック全体を以下に置き換える
(変更点は両メソッド先頭の `str = Wareki::Utils.normalize_time(str)` の1行ずつのみ):

```ruby
  class << self
    alias _wareki_parse_orig parse
    def parse(str = '-4712-01-01', comp = true, start = ::Date::ITALY)
      str = Wareki::Utils.normalize_time(str)
      str.to_s =~ Wareki::PARSE_QUICK_FILTER or
        return ::Date._wareki_parse_orig(str, comp, start)
      Wareki::Date.parse(str).to_date(start)
    rescue Wareki::InvalidDate
      raise
    rescue ArgumentError, Wareki::UnsupportedDateRange
      ::Date._wareki_parse_orig(str, comp, start)
    end

    alias _wareki__parse_orig _parse
    def _parse(str, comp = true)
      str = Wareki::Utils.normalize_time(str)
      str.to_s =~ Wareki::PARSE_QUICK_FILTER or
        return ::Date._wareki__parse_orig(str, comp)
      di = Wareki::Date._parse(str)
      wdate = Wareki::Date.new(di[:era], di[:year], di[:month], di[:day], di[:is_leap])
    rescue ArgumentError, Wareki::UnsupportedDateRange
      ::Date._wareki__parse_orig(str, comp)
    else
      ::Date._wareki__parse_orig(str.sub(Wareki::REGEX, wdate.strftime('%F ')), comp)
    end
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/std_ext_spec.rb`
Expected: PASS(既存例含め全例。特に `Date.parse == Date._wareki_parse_orig`、
`Date._parse('平成元年5月4日12:34:56')`、`Date._parse('completely invalid date') == {}` が
引き続き通ること)

- [ ] **Step 5: Run full suite and rubocop**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: rspec 全て PASS / rubocop はベースラインの 5 offenses のみ(新規なし)

- [ ] **Step 6: Commit**

```bash
git add lib/wareki/std_ext.rb spec/std_ext_spec.rb
git commit -m "Normalize Japanese time notations in patched Date.parse/_parse

Time.parse picks this up automatically since it calls Date._parse."
```

---

### Task 3: Utils.number_format 移動と Utils.expand_time_format (%JT 展開)

**Files:**
- Modify: `lib/wareki/utils.rb`(定数はモジュール先頭、メソッドは `normalize_time` 群の直後)
- Modify: `lib/wareki/date.rb:216-225`(`_number_format` を委譲化)
- Modify: `.rubocop.yml`(Metrics/ModuleLength Max 引き上げ。Utils は現在 116 LOC / Max 120 で、本タスクの追加で超過するため)
- Test: `spec/utils_spec.rb`

**Interfaces:**
- Consumes: `Wareki::Utils.i2z`、`YaKansuji.to_kan(n, :simple)`(既存)
- Produces: `Wareki::Utils.number_format(opt) -> String`(printf 形式)、`Wareki::Utils::TIME_FORMAT_EXPANSION_REGEX`、`Wareki::Utils.expand_time_format(format_str, time) -> String`(`time` は hour/min/sec に応答するオブジェクト。Task 4 が使用)

- [ ] **Step 1: Write the failing tests**

`spec/utils_spec.rb` の Task 1 で追加した `it 'keeps strings without time notation unchanged'` ブロックの直後に追加:

```ruby
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/utils_spec.rb`
Expected: FAIL, `NoMethodError: undefined method 'expand_time_format'`

- [ ] **Step 3: Implement number_format and expand_time_format in Utils**

`lib/wareki/utils.rb` のモジュール冒頭を以下のように変更(`module Utils` の直後、
`module_function` の前に定数を追加):

```ruby
  # Static utility methods.
  module Utils
    TIME_FORMAT_DIRECTIVE_REGEX = /%J(-|[_0]{0,2}[0-9]*|)(T(?:[fF]|[HMS]k?))/.freeze
    TIME_FORMAT_EXPANSION_REGEX = /(?<!%)(?:%%)*\K#{TIME_FORMAT_DIRECTIVE_REGEX}/.freeze

    module_function
```

Task 1 で追加した `_time_match_to_s` メソッドの直後に追加:

```ruby
    def number_format(opt)
      case opt
      when '', '0', '_0' then '%02d'
      when '-'           then '%d'
      when /_\Z/         then '%2d'
      when /0?_/         then "%#{opt.sub(/0?_/, '')}d"
      when /_?0/         then "%#{opt.sub(/_?0/, '0')}d"
      else "%0#{opt}d"
      end
    end

    def expand_time_format(format_str, time)
      format_str.to_str.gsub(TIME_FORMAT_EXPANSION_REGEX) { _format_time_directive($2, $1, time) || $& }
    end

    def _format_time_directive(key, opt, time)
      case key.to_sym
      when :Tf
        nf = number_format(opt)
        Kernel.format("#{nf}時#{nf}分#{nf}秒", time.hour, time.min, time.sec)
      when :TF
        "#{YaKansuji.to_kan(time.hour, :simple)}時#{YaKansuji.to_kan(time.min, :simple)}分" \
        "#{YaKansuji.to_kan(time.sec, :simple)}秒"
      when :TH  then i2z(time.hour)
      when :THk then YaKansuji.to_kan(time.hour, :simple)
      when :TM  then i2z(time.min)
      when :TMk then YaKansuji.to_kan(time.min, :simple)
      when :TS  then i2z(time.sec)
      when :TSk then YaKansuji.to_kan(time.sec, :simple)
      end
    end
```

- [ ] **Step 4: Delegate Wareki::Date#_number_format to Utils**

`lib/wareki/date.rb` の `_number_format` メソッド(既存10行):

```ruby
    def _number_format(opt)
      case opt
      when '', '0', '_0' then '%02d'
      when '-'           then '%d'
      when /_\Z/         then '%2d'
      when /0?_/         then "%#{opt.sub(/0?_/, '')}d"
      when /_?0/         then "%#{opt.sub(/_?0/, '0')}d"
      else "%0#{opt}d"
      end
    end
```

を以下に置き換える:

```ruby
    def _number_format(opt)
      Utils.number_format(opt)
    end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/utils_spec.rb spec/date_spec.rb`
Expected: PASS(date_spec の既存パディングテスト含む)

- [ ] **Step 6: Raise Metrics/ModuleLength cap**

`.rubocop.yml` の

```yaml
Metrics/ModuleLength:
  Max: 120
```

を以下に変更(Utils が時刻正規化・展開の追加で 120 を超えるため。
リポジトリは既に ClassLength 280 など実態に合わせた Max 調整をしている):

```yaml
Metrics/ModuleLength:
  Max: 170
```

- [ ] **Step 7: Run full suite and rubocop**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: rspec 全て PASS / rubocop はベースラインの 5 offenses のみ(新規なし。
Metrics/ModuleLength が出る場合は Step 6 の Max 引き上げ漏れ)

- [ ] **Step 8: Commit**

```bash
git add lib/wareki/utils.rb lib/wareki/date.rb spec/utils_spec.rb .rubocop.yml
git commit -m "Add Utils.expand_time_format for %JT directives

Move number format resolution to Utils.number_format so time and date
formatting share the padding-flag logic."
```

---

### Task 4: Time / DateTime の strftime パッチと Time#to_wareki_date

**Files:**
- Modify: `lib/wareki/std_ext.rb`(`module StdExt`、`class DateTime`、`class Time` 追加)
- Test: `spec/std_ext_spec.rb`

**Interfaces:**
- Consumes: `Wareki::Utils.expand_time_format` / `Wareki::Utils::TIME_FORMAT_EXPANSION_REGEX`(Task 3)、`Wareki::Date#expand_wareki_format`・`Wareki::StdExt.wareki_directive?`(既存)
- Produces: `Time#to_wareki_date`、`Time#strftime`(%J・%JT 対応)、`DateTime#strftime`(%JT 追加対応)、`Wareki::StdExt.wareki_time_directive?` / `Wareki::StdExt.expand_all_wareki_formats`

- [ ] **Step 1: Write the failing tests**

`spec/std_ext_spec.rb` の `it 'supports wareki directives on DateTime' do ... end` ブロックの直後に追加:

```ruby
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

  it 'supports wareki time directives on DateTime' do
    dt = DateTime.new(2019, 5, 4, 13, 45, 6)
    expect(dt.strftime('%JF %JTF')).to eq '令和元年五月四日 十三時四十五分六秒'
    expect(dt.strftime('%JTf')).to eq '13時45分06秒'
    expect(dt.strftime).to eq dt._wareki_strftime_orig
  end

  it 'keeps %JT literal on Date' do
    expect(Date.new(2019, 5, 4).strftime('%JTF')).to eq '%JTF'
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/std_ext_spec.rb`
Expected: FAIL。`t.strftime('%JF %JTF')` がリテラルの `'%JF %JTF'` を返す、
`to_wareki_date` が NoMethodError、DateTime の `%JTf` がリテラルのまま、など。
`keeps %JT literal on Date` は最初から PASS でよい(現状確認のリグレッションガード)

- [ ] **Step 3: Implement StdExt helpers and Time / DateTime patches**

`lib/wareki/std_ext.rb` の `module StdExt ... end` を以下に置き換える:

```ruby
  # :nodoc:
  module StdExt
    module_function

    def wareki_directive?(format)
      !!(format.to_str =~ Wareki::Date::FORMAT_EXPANSION_REGEX)
    end

    def wareki_time_directive?(format)
      !!(format.to_str =~ Wareki::Utils::TIME_FORMAT_EXPANSION_REGEX)
    end

    # %JT 時刻トークンと %J 日付トークンの両方を展開した文字列を返す
    def expand_all_wareki_formats(format, datetime)
      ret = format
      ret = Wareki::Utils.expand_time_format(ret, datetime) if wareki_time_directive?(ret)
      ret = datetime.to_wareki_date.expand_wareki_format(ret) if wareki_directive?(ret)
      ret
    end
  end
```

同ファイルの `class DateTime ... end` を以下に置き換える:

```ruby
# :nodoc:
class DateTime
  alias _wareki_strftime_orig strftime
  def strftime(format = '%FT%T%:z')
    _wareki_strftime_orig(Wareki::StdExt.expand_all_wareki_formats(format, self))
  end
end
```

さらにファイル末尾(`class DateTime` の後)に追加:

```ruby
# :nodoc:
class Time
  def to_wareki_date
    Wareki::Date.jd(to_date.jd)
  end

  alias _wareki_strftime_orig strftime
  def strftime(format)
    _wareki_strftime_orig(Wareki::StdExt.expand_all_wareki_formats(format, self))
  end
end
```

`class Date`(インスタンス側)の `strftime` は変更しない。

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/std_ext_spec.rb`
Expected: PASS(既存の DateTime 例 `dt.strftime('%JF %H:%M:%S')` 等も引き続き通ること)

- [ ] **Step 5: Run full suite and rubocop**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: rspec 全て PASS / rubocop は 6 offenses(ベースライン 5 件 + `class Time` 追加による
Style/OneClassPerFile 1 件。同ファイルの Date/DateTime で既に出ている既存カテゴリのため許容)

- [ ] **Step 6: Commit**

```bash
git add lib/wareki/std_ext.rb spec/std_ext_spec.rb
git commit -m "Support %J/%JT directives in Time#strftime and %JT in DateTime

Add Time#to_wareki_date and StdExt.expand_all_wareki_formats shared by
the Time and DateTime strftime patches."
```

---

### Task 5: README と ChangeLog の更新

**Files:**
- Modify: `README.md`
- Modify: `ChangeLog`(先頭の 2026-07-13 / 2.0.0 エントリ)

**Interfaces:**
- Consumes: Task 1〜4 の成果(記載例が実挙動と一致すること)
- Produces: 利用者向けドキュメント

- [ ] **Step 1: Verify actual outputs for README examples**

Run:

```bash
LANG=C.UTF-8 LC_ALL=C.UTF-8 ruby -Ilib -rtime -rwareki -e '
t = Time.parse("平成元年五月四日 午後三時三十四分五十六秒")
puts t
puts t.strftime("%JF %JTF")
puts t.strftime("%JTf")
puts t.strftime("%JTHk時%JTMk分")
'
```

Expected: `1989-05-04 15:34:56 +0900`(TZ依存)、`平成元年五月四日 十五時三十四分五十六秒`、
`15時34分56秒`、`十五時三十四分`。README に書く例はこの実出力に合わせる(異なったら README 側を直す)。

- [ ] **Step 2: Update README 機能 section**

`## 機能` の `* 和暦文字列のパース` 配下の最後のビュレット
(`* 元年、正月、朔日、晦日、廿一日、卅日 などの特殊な表記の日付サポート`)の直後に追加:

```markdown
  * 時刻の漢数字・全角数字表記のサポート (十二時三十四分五十六秒、午後三時半、正午 など)
```

`* Date クラスの拡張` ブロックの直後に追加:

```markdown
* Time / DateTime クラスの拡張
  * strftime に時刻の全角・漢数字フォーマット文字列 (%JT 系) を追加
  * Time.parse で和暦・漢数字時刻の文字列を解釈 (要 `require 'time'`)
  * Time#to_wareki_date を追加
```

- [ ] **Step 3: Add README usage example**

`### 和暦・旧暦へのフォーマット` セクションの直前に追加(出力コメントは Step 1 の実出力に合わせる):

````markdown
### 時刻のパースとフォーマット

時刻の漢数字・全角数字表記も透過的に扱えます。時刻には暦のようなマッピングは
存在しないため、単純な数字変換として処理されます。

```ruby
require 'time'
t = Time.parse("平成元年五月四日 午後三時三十四分五十六秒")
# => 1989-05-04 15:34:56
t.strftime("%JF %JTF")       # => "平成元年五月四日 十五時三十四分五十六秒"
t.strftime("%JTf")           # => "15時34分56秒"
t.strftime("%JTHk時%JTMk分") # => "十五時三十四分"
```
````

- [ ] **Step 4: Update README format directive list**

`## 追加フォーマット文字列一覧` の `* %JDK: ...` 行の直後に追加:

```markdown

以下の時刻フォーマット文字列は Time / DateTime の strftime でのみ使用できます
(Date は時刻情報を持たないため展開されません)。

* %JTf: "%JTH時%JTM分%JTS秒" 相当の半角ゼロ埋め複合表記 (例: 15時04分05秒)
* %JTF: 漢数字の複合表記 (例: 十五時四分五秒)
* %JTH: 時の全角数字
* %JTHk: 時の漢数字
* %JTM: 分の全角数字
* %JTMk: 分の漢数字
* %JTS: 秒の全角数字
* %JTSk: 秒の漢数字
```

- [ ] **Step 5: Update README 仕様、限界、制限など section**

`## 仕様、限界、制限など` のリスト末尾に追加:

```markdown
* 時刻の解釈・出力は単純な数字変換のみで、十二時辰などの伝統的時刻制度との対応はありません
* 時刻パース時、「午前」は無変換、「午後」は12時未満の時にのみ+12します (午後十二時 → 12:00)
* 「三時間」「13時代」のような「数字+時」を含む複合語も時刻として解釈されることがあります (このため、従来 Date.parse が数字を日として解釈して成功していた文字列がエラーになる場合があります)
* 範囲外の時刻 (二十五時など) は ASCII 表記 (25:00) と同様に扱われ、Time.parse では通常 ArgumentError になります
```

- [ ] **Step 6: Update ChangeLog**

`ChangeLog` 先頭エントリ(`2026-07-13  Tatsuki Sugiura`)の `* Version: 2.0.0` 行の直後に追加
(インデントはタブ1つ、既存行と同じ):

```
	* Time.parse now understands Japanese kansuji/zenkaku time notations
	  (十二時三十四分五十六秒, 午後三時半, 正午, ...) via the patched
	  Date._parse; Date.parse no longer misreads bare 時分秒 strings
	* Add %JT* time format directives (%JTf/%JTF/%JTH(k)/%JTM(k)/%JTS(k));
	  Time#strftime now supports all %J directives and DateTime#strftime
	  expands %JT too; add Time#to_wareki_date
```

- [ ] **Step 7: Run full suite and rubocop**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: rspec 全て PASS / rubocop は 6 offenses(Task 4 終了時点と同じ。ドキュメントのみの変更だが最終確認として)

- [ ] **Step 8: Commit**

```bash
git add README.md ChangeLog
git commit -m "Document kansuji time parsing and %JT format directives"
```
