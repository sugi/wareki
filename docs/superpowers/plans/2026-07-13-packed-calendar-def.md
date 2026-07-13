# Bit-Packed Calendar Definitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 旧暦テーブル (YEAR_DEFS: Struct 1428個 + 配列 2856個 + Hash, 約554KB) を「1年 = 整数1個 (40bit)」のビットパック表現 (約11.4KB, 1/48) に置き換え、ロードを約55倍高速化する。あわせて gemspec の required_ruby_version を 2.3 に引き上げる。

**Architecture:** 新モジュール `Wareki::Calendar` に参照ロジック (`lib/wareki/calendar.rb`, 手書き) とデータ (`lib/wareki/calendar_def.rb`, 自動生成) を分離して置く。移行中は旧 `YEAR_DEFS` から詰め替える一時ブートストラップで `Calendar::PACKED` を構築し、全消費側 (`utils.rb` / `date.rb` / `common.rb`) を `Calendar` API に切り替えたあと、ジェネレータ (`build-util/gen-jp-cal-def.rb`) を新形式出力に書き換えて生成データで置換する。`Wareki::YEAR_DEFS` / `Wareki::YEAR_BY_NUM` / `Wareki::Year` / `Wareki::Utils.find_year` は削除する (互換維持は不要と指示済み)。

**Tech Stack:** Pure Ruby (>= 2.3)。`Array#bsearch_index` (2.3+) を使用。RSpec + RuboCop。

## Global Constraints

- **作業場所 (最重要):** すべての作業は worktree `/home/sugi/works/git/github/wareki/.claude/worktrees/feat+packed-calendar-def` で行う。サブエージェントはメイン checkout (`/home/sugi/works/git/github/wareki`) で起動するため、**必ず最初に worktree へ cd し、`git branch --show-current` が `feat/packed-calendar-def` であることを確認してから作業を開始する**。メイン checkout のファイルには一切触れない (Task 4 のデータソースコピーの読み取りを除く)。
- **Ruby バージョン:** worktree には `.ruby-version` (2.7.8) 配置済み。テストは `bundle exec rspec`、lint は `bundle exec rubocop`。新規コードは **Ruby 2.3 で動くこと**: `unpack1`, `String#match?`, `Integer#digits`, `Comparable#clamp`, `yield_self`, `then` は使用禁止。`Array#bsearch_index` は 2.3+ なので使用可。
- **RuboCop:** `.rubocop.yml` は `lib/wareki/*_def.rb` を除外済み (生成ファイルは lint 対象外)。手書きの `lib/wareki/calendar.rb` は lint 対象。**注意: master 時点で spec/ に既存 offense が12件ある** (FrozenStringLiteralComment / RSpec/LeakyLocalVariable。CI は rspec のみなので放置されている)。これらの修正はスコープ外。各タスクの `bundle exec rubocop` の期待値は「no offenses」ではなく「**この既存12件以外の新規 offense がないこと**」と読み替える。`Style/NumericPredicate: comparison` (`.zero?` でなく `== 0` を使う)、`Style/AndOr: conditionals` に注意。Metrics 系で `find_date_ary` / `to_jd` が引っかかった場合のみ、そのメソッド前後を `# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity` / `# rubocop:enable ...` で囲む (ビット演算をフラットに並べるのは速度目的で意図的)。
- **コミット:** メッセージは英語・命令形一行 (例: `Cache small kansuji format values`)。本文末尾に以下のトレーラを付ける:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_019zprNf9ALwJ5UgyB4hf3cK
  ```
  `git add` は対象ファイルを明示指定 (`git add -A` 禁止。特に `kyuureki-map.txt` (22MB データソース) を絶対にコミットしない)。
- **一時ファイル:** `/tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad` を使う。
- **挙動維持:** 削除対象 (`YEAR_DEFS` / `YEAR_BY_NUM` / `Wareki::Year` / `Utils.find_year`) 以外の公開挙動は完全に維持する。既存 spec は削除対象に触れる箇所以外、一切変更しない。

### ビットレイアウト (全タスク共通の前提)

1年分の旧暦情報を整数1個 (40bit, Fixnum に収まる) に詰める。`PACKED[西暦年 - YEAR_MIN]`:

| bits | 内容 |
|---|---|
| 0..21 | その年の最初の月の初日のユリウス通日 (JD, 最大 2405159 < 2^22) |
| 22..34 | 月の大小マスク (bit i = その年 i 番目の月が大の月 = 30日。小の月 = 29日) |
| 35 | 閏月を含む13ヶ月の年なら 1 |
| 36..39 | 閏月の月番号 (1..12、閏月がなければ 0) |

特例: 明治5年12月 (テーブル最終月) はグレゴリオ暦切替のため **2日** で打ち切り。マスクでは表現できないので、参照側は「`YEAR_MAX` の最終月」を `LAST_MONTH_DAYS` (= 2) 日として扱う。

検証済みの事実 (このプラン作成時に全域検証済み):
- 年は 445..1872 で連続 (1428年)、暦は完全連続 (前年末日+1 = 翌年初日)
- `Year#end` = 最終月初 + 最終月日数 - 1 で全年一致
- 旧 `Year#start` は閏1月の年 (43年分) だけ `month_starts[1]` を指す癖があるが、`start` の利用箇所は `find_year` の下限ガードのみで、年445は閏1月でないため `JD_MIN` = 1883618 で完全互換

---

### Task 1: gemspec の required_ruby_version を 2.3 に引き上げ

**Files:**
- Modify: `wareki.gemspec:28`
- Modify: `.rubocop.yml` (コメント2箇所)

**Interfaces:**
- Consumes: なし
- Produces: なし (宣言変更のみ)

- [ ] **Step 1: gemspec を変更**

`wareki.gemspec` の

```ruby
  spec.required_ruby_version = '>= 2.0.0'
```

を

```ruby
  spec.required_ruby_version = '>= 2.3.0'
```

に変更。

- [ ] **Step 2: .rubocop.yml の陳腐化したコメントを更新**

```yaml
Gemspec/RequiredRubyVersion:
  Exclude:
    - 'wareki.gemspec' # Required to support 2.0
```

を

```yaml
Gemspec/RequiredRubyVersion:
  Exclude:
    - 'wareki.gemspec' # Required to support 2.3
```

に、

```yaml
Style/NumericPredicate:
  EnforcedStyle: comparison # For ruby < 2.3
```

を

```yaml
Style/NumericPredicate:
  EnforcedStyle: comparison
```

に変更 (スタイル自体は既存コードが準拠しているため維持)。

- [ ] **Step 3: テストと lint を実行**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: `93 examples, 0 failures` / `no offenses detected`

- [ ] **Step 4: Commit**

```bash
git add wareki.gemspec .rubocop.yml
git commit -m "Raise required Ruby version to 2.3"
```
(トレーラ付き)

---

### Task 2: Wareki::Calendar 参照モジュール (一時ブートストラップ) + spec

**Files:**
- Create: `lib/wareki/calendar.rb`
- Create: `spec/calendar_spec.rb`

**Interfaces:**
- Consumes: `Wareki::YEAR_DEFS` (旧 calendar_def.rb。ブートストラップからのみ参照)
- Produces: `Wareki::Calendar` — 後続タスクが依存する API:
  - 定数 `YEAR_MIN` (=445), `YEAR_MAX` (=1872), `JD_MIN` (=1883618), `JD_MAX` (=2405159), `LAST_MONTH_DAYS` (=2), `PACKED` (Integer×1428, frozen)
  - `covers_year?(year) → bool` / `covers_jd?(jd) → bool`
  - `leap_month(year) → Integer | nil` (閏月なし・範囲外は nil)
  - `month_index(year, month, is_leap) → Integer` (0始まり月添字。year 範囲内は呼び出し側が保証)
  - `last_day_of_month(year, month, is_leap) → Integer | nil` (範囲外 nil)
  - `to_jd(year, month, day, is_leap) → Integer | nil` (範囲外 nil)
  - `find_date_ary(jd) → [year, month, day, is_leap] | nil` (範囲外 nil)

- [ ] **Step 1: 失敗する spec を書く**

`spec/calendar_spec.rb` を以下の内容で作成:

```ruby
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
```

- [ ] **Step 2: spec が失敗することを確認**

Run: `bundle exec rspec spec/calendar_spec.rb`
Expected: FAIL (`cannot load such file -- wareki/calendar`)

- [ ] **Step 3: lib/wareki/calendar.rb を実装**

以下の内容で作成 (ブートストラップ部は Task 4 で生成データに置換される):

```ruby
# frozen_string_literal: true

require 'wareki/calendar_def'

module Wareki
  # 旧暦テーブルの参照ロジック。1年分の旧暦情報は整数1個 (40bit) に
  # ビットパックされている。PACKED[西暦年 - YEAR_MIN]:
  #   bits 0..21  : その年の最初の月の初日のユリウス通日 (JD)
  #   bits 22..34 : 月の大小マスク (bit i = i 番目の月が大の月 = 30日)
  #   bit  35     : 閏月を含む13ヶ月の年なら1
  #   bits 36..39 : 閏月の月番号 (1..12、閏月がなければ0)
  # 明治5年12月 (テーブル最終月) はグレゴリオ暦切替のため LAST_MONTH_DAYS
  # (= 2) 日で打ち切られており、大小マスクには反映されていない。
  module Calendar
    # 一時ブートストラップ: 旧形式 YEAR_DEFS から詰め替えて定数を構築する。
    # build-util/gen-jp-cal-def.rb が生成する新形式 calendar_def.rb に置換予定。
    YEAR_MIN = YEAR_DEFS.first.year
    YEAR_MAX = YEAR_DEFS.last.year
    JD_MIN = YEAR_DEFS.first.month_starts.first
    JD_MAX = YEAR_DEFS.last.end
    LAST_MONTH_DAYS = YEAR_DEFS.last.month_days.last
    PACKED = YEAR_DEFS.map do |y|
      mask = 0
      y.month_days.each_with_index { |d, i| mask |= (1 << i) if d == 30 }
      (y.leap_month || 0) << 36 | (y.month_starts.size - 12) << 35 |
        mask << 22 | y.month_starts.first
    end.freeze
    # ブートストラップここまで

    module_function

    def covers_year?(year)
      year >= YEAR_MIN && year <= YEAR_MAX
    end

    def covers_jd?(jd)
      jd >= JD_MIN && jd <= JD_MAX
    end

    # 閏月の月番号。閏月のない年・範囲外の年は nil
    def leap_month(year)
      covers_year?(year) or return nil
      lp = PACKED[year - YEAR_MIN] >> 36
      lp == 0 ? nil : lp
    end

    # 月番号 (1始まり) を月配列添字 (閏月込み・0始まり) に変換する。
    # year がテーブル範囲内であることは呼び出し側が保証すること。
    def month_index(year, month, is_leap)
      lp = leap_month(year)
      idx = month - 1
      is_leap || (lp && month > lp) and idx += 1
      idx
    end

    def last_day_of_month(year, month, is_leap)
      covers_year?(year) or return nil
      packed = PACKED[year - YEAR_MIN]
      idx = month_index(year, month, is_leap)
      months = 12 + ((packed >> 35) & 1)
      return LAST_MONTH_DAYS if year == YEAR_MAX && idx == months - 1

      29 + ((packed >> (22 + idx)) & 1)
    end

    def to_jd(year, month, day, is_leap)
      covers_year?(year) or return nil
      packed = PACKED[year - YEAR_MIN]
      idx = month_index(year, month, is_leap)
      jd = packed & 0x3fffff
      i = 0
      while i < idx
        jd += 29 + ((packed >> (22 + i)) & 1)
        i += 1
      end
      jd + day - 1
    end

    # jd を [西暦年, 月, 日, 閏月フラグ] に変換する。範囲外は nil
    def find_date_ary(jd)
      covers_jd?(jd) or return nil
      i = PACKED.bsearch_index { |packed| (packed & 0x3fffff) > jd }
      i = i.nil? ? PACKED.size - 1 : i - 1
      packed = PACKED[i]
      month_start = packed & 0x3fffff
      months = 12 + ((packed >> 35) & 1)
      lp = packed >> 36
      idx = 0
      while idx < months - 1
        next_start = month_start + 29 + ((packed >> (22 + idx)) & 1)
        break if jd < next_start

        month_start = next_start
        idx += 1
      end
      month = idx + 1
      month -= 1 if lp != 0 && lp < month
      [YEAR_MIN + i, month, jd - month_start + 1, lp != 0 && lp == idx]
    end
  end
end
```

- [ ] **Step 4: spec が通ることを確認**

Run: `bundle exec rspec spec/calendar_spec.rb`
Expected: `8 examples, 0 failures` (roundtrip の例は全521,542日を走査するため数秒かかる)

- [ ] **Step 5: 旧実装との全域一致検証 (一回限り、コミットしない)**

scratchpad に `verify_equivalence.rb` を以下の内容で作成し、worktree から実行:

```ruby
# frozen_string_literal: true
# 旧実装 (YEAR_DEFS) と Wareki::Calendar の全域一致検証 (一回限り)
$LOAD_PATH.unshift 'lib'
require 'wareki/calendar'

c = Wareki::Calendar
defs = Wareki::YEAR_DEFS

old_find = lambda do |jd|
  yobj = jd < defs.first.start ? nil : defs.bsearch { |y| y.end >= jd }
  next nil if yobj.nil?
  month = if yobj.month_starts.last <= jd
            yobj.month_starts.count
          else
            yobj.month_starts.find_index { |m| jd <= (m - 1) }
          end
  month_start = yobj.month_starts[month - 1]
  is_leap = (yobj.leap_month == (month - 1))
  yobj.leap_month && yobj.leap_month < month and month -= 1
  [yobj.year, month, jd - month_start + 1, is_leap]
end

((c::JD_MIN - 2)..(c::JD_MAX + 2)).each do |jd|
  o = old_find.call(jd)
  n = c.find_date_ary(jd)
  o == n or abort "find_date_ary mismatch jd=#{jd}: old=#{o.inspect} new=#{n.inspect}"
end

defs.each do |y|
  (1..12).each do |mon|
    leaps = y.leap_month == mon ? [false, true] : [false]
    leaps.each do |lp|
      idx = mon - 1
      idx += 1 if lp || (y.leap_month && mon > y.leap_month)
      y.month_days[idx] == c.last_day_of_month(y.year, mon, lp) or
        abort "last_day mismatch #{y.year}/#{mon} leap=#{lp}"
      y.month_starts[idx] == c.to_jd(y.year, mon, 1, lp) or
        abort "to_jd mismatch #{y.year}/#{mon} leap=#{lp}"
    end
  end
end
puts "equivalence: all OK (#{c::JD_MAX - c::JD_MIN + 1} days, #{defs.size} years)"
```

Run: `ruby /tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/verify_equivalence.rb`
Expected: `equivalence: all OK (521542 days, 1428 years)`

- [ ] **Step 6: 全 spec と lint**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: `101 examples, 0 failures` / `no offenses detected` (Metrics 違反が出た場合のみ Global Constraints 記載の narrow disable を追加)

- [ ] **Step 7: Commit**

```bash
git add lib/wareki/calendar.rb spec/calendar_spec.rb
git commit -m "Add bit-packed calendar lookup module"
```
(トレーラ付き)

---

### Task 3: 消費側を Wareki::Calendar に移行し、旧 API を削除

**Files:**
- Modify: `lib/wareki/common.rb` (require 変更、YEAR_BY_NUM 削除)
- Modify: `lib/wareki/utils.rb` (`_last_day_of_month_from_defs`, `find_date_ary`, `find_year` 削除)
- Modify: `lib/wareki/date.rb` (`month_index`, `_validate_date!`, `jd`)
- Modify: `spec/utils_spec.rb` (find_year 参照2例、deep-freeze 1例)

**Interfaces:**
- Consumes: Task 2 の `Wareki::Calendar` API (シグネチャは Task 2 の Produces 参照)
- Produces: 外部挙動は従来と同一。`Wareki::Utils.find_year` と `Wareki::YEAR_BY_NUM` は削除済みになる

- [ ] **Step 1: spec を先に更新 (挙動維持なので更新後も旧実装で green のはず)**

`spec/utils_spec.rb` の

```ruby
  it 'can find year with first and last day' do
    expect(u.find_year(2_275_903).year).to eq 1519
    expect(u.find_year(2_276_257).year).to eq 1519
    expect(u.find_year(2_293_061).year).to eq 1566
    expect(u.find_year(2_293_443).year).to eq 1566
  end
```

を

```ruby
  it 'can find year with first and last day' do
    expect(u.find_date_ary(2_275_903)[0]).to eq 1519
    expect(u.find_date_ary(2_276_257)[0]).to eq 1519
    expect(u.find_date_ary(2_293_061)[0]).to eq 1566
    expect(u.find_date_ary(2_293_443)[0]).to eq 1566
  end
```

に、

```ruby
  it 'returns nil for jd before the year table' do
    expect(u.find_year(1_883_617)).to be_nil
    expect(u.find_year(1_883_618).year).to eq 445
  end
```

を

```ruby
  it 'rejects jd before the year table' do
    expect { u.find_date_ary(1_883_617) }.to raise_error(Wareki::UnsupportedDateRange)
    expect(u.find_date_ary(1_883_618)).to eq [445, 1, 1, false]
  end
```

に、`it 'deep freezes calendar year definitions' do ... end` のブロック全体 (YEAR_DEFS/YEAR_BY_NUM/Year struct を参照する13行) を

```ruby
  it 'freezes calendar definitions' do
    expect(Wareki::Calendar::PACKED).to be_frozen
  end
```

に置き換える。直後の `it 'keeps historical lunisolar conversion working with frozen definitions'` は変更しない。

- [ ] **Step 2: 更新後の spec が旧実装のまま通ることを確認**

Run: `bundle exec rspec`
Expected: `101 examples, 0 failures`

- [ ] **Step 3: lib/wareki/common.rb を変更**

```ruby
require 'wareki/calendar_def'
```

を

```ruby
require 'wareki/calendar'
```

に変更し、次の行を削除:

```ruby
  YEAR_BY_NUM = Hash[*YEAR_DEFS.map { |y| [y.year, y] }.flatten].freeze
```

- [ ] **Step 4: lib/wareki/utils.rb を変更**

`_last_day_of_month_from_defs` を

```ruby
    def _last_day_of_month_from_defs(year, month, is_leap)
      Calendar.last_day_of_month(year, month, is_leap) or
        raise UnsupportedDateRange, "Cannot find year #{year}"
    end
```

に、`find_date_ary` を

```ruby
    def find_date_ary(d)
      d = _to_date(d).new_start(::Date::GREGORIAN)
      d.jd >= GREGORIAN_START and
        return [d.year, d.month, d.day, false]

      Calendar.find_date_ary(d.jd) or
        raise UnsupportedDateRange, "Unsupported date: #{d.inspect}"
    end
```

に置き換え、`find_year` メソッド (5行) を丸ごと削除する:

```ruby
    def find_year(d)
      jd = _to_jd(d)
      jd < YEAR_DEFS.first.start and return nil
      YEAR_DEFS.bsearch { |y| y.end >= jd }
    end
```

- [ ] **Step 5: lib/wareki/date.rb を変更**

`month_index` を

```ruby
    def month_index
      return month - 1 if
        WESTERN_ERA_NAMES.include?(@era_name) || @year >= GREGORIAN_START_YEAR

      Calendar.covers_year?(@year) or
        raise UnsupportedDateRange, "Cannot get year info of #{inspect}"
      Calendar.month_index(@year, month, leap_month?)
    end
```

に、`_validate_date!` の旧暦側分岐 (if 節の中身) を

```ruby
      if !WESTERN_ERA_NAMES.include?(@era_name) && @year < GREGORIAN_START_YEAR
        # 暦テーブル外の年は従来どおり jd 変換時の UnsupportedDateRange に委ねる
        Calendar.covers_year?(@year) or return
        !leap_month? || Calendar.leap_month(@year) == month or
          raise InvalidDate, "invalid date (no leap month): #{inspect}"
        day <= Calendar.last_day_of_month(@year, month, leap_month?) or
          raise InvalidDate, "invalid date (day out of range): #{inspect}"
      else
```

に (else 節は変更しない)、`jd` メソッド末尾の

```ruby
      yobj = YEAR_BY_NUM[@year] or
        raise UnsupportedDateRange, "Cannot convert to jd #{inspect}"
      @jd = yobj.month_starts[month_index] + day - 1
    end
```

を

```ruby
      @jd = Calendar.to_jd(@year, month, day, leap_month?) or
        raise UnsupportedDateRange, "Cannot convert to jd #{inspect}"
      @jd
    end
```

に置き換える (メソッドを閉じる `end` は1つのまま。`@jd = expr or raise` は `(@jd = expr) or raise` と解釈される。expr が nil のときのみ raise)。

- [ ] **Step 6: 旧 API 参照が残っていないことを確認**

Run: `grep -rn "YEAR_BY_NUM\|find_year" lib/ spec/`
Expected: ヒットなし

Run: `grep -rn "YEAR_DEFS" lib/ spec/`
Expected: `lib/wareki/calendar_def.rb` (旧データ本体) と `lib/wareki/calendar.rb` (ブートストラップ) のみ

- [ ] **Step 7: 全 spec と lint**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: `101 examples, 0 failures` / `no offenses detected`

- [ ] **Step 8: Commit**

```bash
git add lib/wareki/common.rb lib/wareki/utils.rb lib/wareki/date.rb spec/utils_spec.rb
git commit -m "Migrate calendar consumers to Wareki::Calendar"
```
(トレーラ付き)

---

### Task 4: ジェネレータ書き換えと生成データへの置換 (旧 YEAR_DEFS 削除)

**Files:**
- Modify: `build-util/gen-jp-cal-def.rb` (全面書き換え)
- Modify: `lib/wareki/calendar_def.rb` (生成出力で全面置換)
- Modify: `lib/wareki/calendar.rb` (ブートストラップ削除)

**Interfaces:**
- Consumes: `Wareki::Calendar` のブートストラップ定数 (置換前の検証基準として)
- Produces: 生成された `lib/wareki/calendar_def.rb` が `Wareki::Calendar` の定数 (`YEAR_MIN`/`YEAR_MAX`/`JD_MIN`/`JD_MAX`/`LAST_MONTH_DAYS`/`PACKED`) を定義。`Wareki::Year` / `Wareki::YEAR_DEFS` は消滅

- [ ] **Step 1: データソースをメイン checkout からコピー**

```bash
cp /home/sugi/works/git/github/wareki/kyuureki-map.txt .
```

(22MB、git 管理外。コミット禁止)

- [ ] **Step 2: build-util/gen-jp-cal-def.rb を全面書き換え**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Usage: ruby build-util/gen-jp-cal-def.rb kyuureki-map.txt > lib/wareki/calendar_def.rb
#
# You can get kyuureki-map.txt from
# https://raw.githubusercontent.com/manakai/data-locale/master/data/calendar/kyuureki-map.txt
#
# 出力は「1年 = 整数1個 (40bit)」のビットパック表現。
# レイアウトは lib/wareki/calendar.rb のコメントを参照。
#
require 'date'

YEAR_MIN = 445

calinfo = Hash.new { |h, k| h[k] = {month_starts: [], month_days: []} }

ARGF.each do |line|
  line =~ /^(?<gy>[0-9]+)-(?<gm>[0-9]+)-(?<gd>[0-9]+)\s+(?<jy>[0-9]+)-(?<jm>[0-9]+)(?<jl>')?-(?<jd>[0-9]+)/ or next
  gdate = Date.new($~[:gy].to_i, $~[:gm].to_i, $~[:gd].to_i, Date::GREGORIAN)
  gdate.year == 1873 and break
  year  = $~[:jy].to_i
  month = $~[:jm].to_i
  leap  = !!$~[:jl]
  cy = calinfo[year]
  if $~[:jd].to_i == 1
    cy[:month_starts] << gdate.jd
    if leap
      cy[:leap] and raise "#{year} already has leap month (#{cy[:leap]} vs #{month})"
      cy[:leap] = month
    end
  end
  cy[:month_days][cy[:month_starts].count - 1] = gdate.jd - cy[:month_starts].last + 1
end

years = calinfo.keys.select { |y| y >= YEAR_MIN }.sort
years == (years.first..years.last).to_a or raise 'years are not contiguous'

packed_list = []
prev_end = nil
years.each do |y|
  d = calinfo[y]
  ms = d[:month_starts]
  days = d[:month_days]
  ms.size == days.size or raise "year #{y}: month starts/days count mismatch"
  [12, 13].include?(ms.size) or raise "year #{y}: unexpected month count #{ms.size}"
  (ms.size == 13) == !d[:leap].nil? or raise "year #{y}: leap flag inconsistent with month count"
  d[:leap].nil? || (1..12).cover?(d[:leap]) or raise "year #{y}: leap month out of range"
  prev_end.nil? || ms.first == prev_end + 1 or raise "year #{y}: calendar not contiguous"
  ms.first < (1 << 22) or raise "year #{y}: JD overflows 22bit"
  ms.each_cons(2).zip(days).all? { |(a, b), dd| b - a == dd } or
    raise "year #{y}: month days inconsistent with month starts"
  days[0..-2].all? { |dd| dd == 29 || dd == 30 } or raise "year #{y}: month days out of range"
  y == years.last || days.last == 29 || days.last == 30 or raise "year #{y}: month days out of range"
  mask = 0
  days.each_with_index { |dd, i| mask |= (1 << i) if dd == 30 }
  packed_list << ((d[:leap] || 0) << 36 | (ms.size - 12) << 35 | mask << 22 | ms.first)
  prev_end = ms.last + days.last - 1
end

puts <<~HEADER
  # frozen_string_literal: true

  # 旧暦カレンダー定義データ (#{years.first}年-#{years.last}年)。
  # build-util/gen-jp-cal-def.rb による自動生成。手動編集しないこと。
  # 再生成: ruby build-util/gen-jp-cal-def.rb kyuureki-map.txt > lib/wareki/calendar_def.rb
  # 元データ: https://raw.githubusercontent.com/manakai/data-locale/master/data/calendar/kyuureki-map.txt
  # 各要素のビットレイアウトは lib/wareki/calendar.rb のコメントを参照。
  module Wareki
    module Calendar
      YEAR_MIN = #{years.first}
      YEAR_MAX = #{years.last}
      JD_MIN = #{calinfo[years.first][:month_starts].first}
      JD_MAX = #{prev_end}
      LAST_MONTH_DAYS = #{calinfo[years.last][:month_days].last}
      PACKED = [
HEADER
packed_list.each_slice(6) do |slice|
  puts "        #{slice.map { |p| format('0x%010x', p) }.join(', ')},"
end
puts <<~FOOTER
      ].freeze
    end
  end
FOOTER
```

- [ ] **Step 3: 生成して一時ファイルに出力**

```bash
ruby build-util/gen-jp-cal-def.rb kyuureki-map.txt > /tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/calendar_def_new.rb
```

Expected: エラーなく終了 (ジェネレータ内の invariant チェックがすべて通過)

- [ ] **Step 4: 生成データとブートストラップ値の完全一致を検証**

置換前 (ブートストラップがまだ有効なうち) に、worktree で:

```bash
ruby -Ilib -e 'require "wareki/calendar"; c = Wareki::Calendar; File.binwrite("/tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/bootstrap.dump", Marshal.dump([c::YEAR_MIN, c::YEAR_MAX, c::JD_MIN, c::JD_MAX, c::LAST_MONTH_DAYS, c::PACKED]))'
ruby -e 'load "/tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/calendar_def_new.rb"; c = Wareki::Calendar; expected = Marshal.load(File.binread("/tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/bootstrap.dump")); actual = [c::YEAR_MIN, c::YEAR_MAX, c::JD_MIN, c::JD_MAX, c::LAST_MONTH_DAYS, c::PACKED]; actual == expected ? puts("generated data identical") : abort("GENERATED DATA MISMATCH")'
```

Expected: `generated data identical`
(不一致の場合は作業を止めて報告すること。ローカルの kyuureki-map.txt がコミット済みデータより新しい可能性がある)

- [ ] **Step 5: 生成ファイルで旧 calendar_def.rb を置換し、ブートストラップを削除**

```bash
cp /tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/calendar_def_new.rb lib/wareki/calendar_def.rb
```

`lib/wareki/calendar.rb` から「一時ブートストラップ」ブロック (コメント行 `# 一時ブートストラップ: ...` と `# build-util/gen-jp-cal-def.rb が生成する...` から `# ブートストラップここまで` まで、`YEAR_MIN`〜`PACKED` の定数定義を含む全行) を削除する。`require 'wareki/calendar_def'` と `module_function` 以降のメソッド定義はそのまま残す。

- [ ] **Step 6: 全 spec と lint**

Run: `bundle exec rspec && bundle exec rubocop`
Expected: `101 examples, 0 failures` / `no offenses detected`

Run: `grep -rn "YEAR_DEFS\|Wareki::Year\b" lib/ spec/`
Expected: ヒットなし

- [ ] **Step 7: Commit**

```bash
git add build-util/gen-jp-cal-def.rb lib/wareki/calendar_def.rb lib/wareki/calendar.rb
git commit -m "Generate bit-packed calendar definitions"
```

(トレーラ付き。`git status` で kyuureki-map.txt がステージされていないことを確認してからコミット)

---

### Task 5: 最終検証・ChangeLog・バージョン

**Files:**
- Modify: `ChangeLog` (先頭に stanza 追加)
- Modify: `lib/wareki/version.rb`

**Interfaces:**
- Consumes: 完成した実装一式
- Produces: リリースノートと計測値 (PR 説明用)

- [ ] **Step 1: rake デフォルト (spec + lint) を実行**

Run: `bundle exec rake`
Expected: `101 examples, 0 failures` / `no offenses detected`

- [ ] **Step 2: Ruby 2.3.8 での互換確認**

構文チェック (必須):

```bash
for f in lib/wareki/*.rb lib/*.rb; do RBENV_VERSION=2.3.8 ruby -c "$f" || echo "SYNTAX NG: $f"; done
```

Expected: すべて `Syntax OK`

機能スモーク (ベストエフォート): `RBENV_VERSION=2.3.8 gem list ya_kansuji` で有無を確認し、なければ `RBENV_VERSION=2.3.8 gem install ya_kansuji` を試す。インストールできたら、scratchpad に `smoke23.rb` を以下の内容で作成して実行 (`ruby -e` に多バイト文字を渡すとロケール次第で `invalid multibyte char` になるため、必ずスクリプトファイル経由で実行すること):

```ruby
# frozen_string_literal: true

require 'wareki'
d = Wareki::Date.parse('天和三年閏五月四日')
raise 'parse NG' unless d.to_date(Date::GREGORIAN) == Date.new(1683, 6, 28, Date::GREGORIAN)
raise 'format NG' unless Wareki::Date.date(Date.new(1683, 6, 28, Date::GREGORIAN)).strftime == '天和三年閏五月四日'
puts '2.3.8 smoke OK'
```

Run: `RBENV_VERSION=2.3.8 ruby -Ilib /tmp/claude-1000/-home-sugi-works-git-github-wareki/41e4006f-36c8-4cc7-a346-b44c5c6c6e58/scratchpad/smoke23.rb`
Expected: `2.3.8 smoke OK` (gem インストール不可の環境なら構文チェックのみで可。その旨を報告に含める)

- [ ] **Step 3: メモリ・ロード時間の計測 (PR 説明用に記録)**

```bash
ruby -Ilib -robjspace -e 'require "wareki/calendar"; puts "PACKED memsize: #{ObjectSpace.memsize_of(Wareki::Calendar::PACKED)} bytes"'
ruby -e 't0 = Process.clock_gettime(Process::CLOCK_MONOTONIC); require File.expand_path("lib/wareki/calendar_def"); printf("calendar_def load: %.2fms\n", (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000)'
```

Expected: memsize 約11.4KB / load 1ms 未満。値を記録して報告に含める。

- [ ] **Step 4: version.rb と ChangeLog を更新**

`lib/wareki/version.rb` の `VERSION = '2.0.0'` を `VERSION = '2.1.0'` に変更。

`ChangeLog` の先頭に以下の stanza を追加 (インデントはタブ。既存 stanza と空行1つで区切る):

```
2026-07-13  Tatsuki Sugiura  <sugi@nemui.org>

	* Version: 2.1.0
	* Shrink in-memory kyuureki calendar table to ~1/48 (bit-packed
	  one-integer-per-year representation in new internal module
	  Wareki::Calendar); calendar definitions now load ~50x faster
	* Remove internal constants Wareki::YEAR_DEFS, Wareki::YEAR_BY_NUM,
	  Wareki::Year and Wareki::Utils.find_year
	* required_ruby_version is now >= 2.3

```

- [ ] **Step 5: 最終確認と Commit**

Run: `bundle exec rake`
Expected: green

```bash
git add ChangeLog lib/wareki/version.rb
git commit -m "Bump version to 2.1.0"
```
(トレーラ付き)

Run: `git log --oneline origin/master..HEAD`
Expected: Task 1〜5 の5コミットが順に並ぶ
