# Time.parse / Time#strftime 漢数字時刻サポート 設計書

日付: 2026-07-13
ステータス: 承認済み(実装前)

## 背景と目的

wareki は現状 Date.parse / Date#strftime のみを拡張している。これに加え、時刻の
日本語表記(漢数字・全角数字の時分秒)のパースとフォーマットをサポートする。
時刻には元号のようなマッピングは存在しないため、単純な数字変換に徹する。

事前調査で判明している現状(2.0.0 向け master、PR #23 マージ後):

- `Time.parse` は内部で `Date._parse` を呼ぶため、`Time.parse("平成元年5月4日 12:34:56")`
  は現状でも動作する。対応すべきは漢数字時刻の解釈である。
- `Date._parse("12時34分56秒")` は Ruby 標準パーサが `{mday: 12}` と誤解釈する。
  同様に `Date.parse("12時34分")` は 12 日の日付を返してしまう。
- DateTime#strftime の %J 日付指示子対応は PR #23 で実装済み。残るは %JT 時刻
  指示子の追加のみ。
- Wareki::Date には `expand_wareki_format`(%J トークン展開、`%%` エスケープ対応)が
  既に存在する。フォーマット側はこれを共用する。
- std_ext の parse/_parse には `PARSE_QUICK_FILTER`(/[年月日]|元旦|弥生|師走/)による
  早期リターンがあり、時刻正規化はこのフィルタより前に行う必要がある。
- 既存 `%Jf` の数値はデフォルト `%02d` パディングで、`%J-f` 等のフラグで制御できる。
- Ruby 標準は "25:00" を `{hour: 25}` と解釈し、Time.parse は
  ArgumentError (hour out of range) を上げる(検証済み)。

## スコープ

対応する:

- 漢数字・全角数字・半角数字 + 時/分/秒 のパース(例: 十二時三十四分五十六秒、１２時３４分)
- 午前/午後(午後三時 → 15:00)
- 「半」(三時半 → 3:30)
- 「正午」(→ 12:00。零時・〇時は数字として自然に解釈されるため特別扱い不要)
- Time#strftime / DateTime#strftime への %JT 時刻指示子の新設
  (Time#strftime は %J 日付系も併せて新規対応。DateTime の %J 日付系は対応済み)
- `Time#to_wareki_date` の追加(Date#to_wareki_date と対になる公開メソッド)

対応しない:

- `Time.strptime`(フォーマット指示子によるパース側の対応)
- `Wareki::Date` への時刻情報の保持(Wareki::Time のような値オブジェクトも作らない)
- 「三時間」のような時間量表現(「三時」部分が時刻として翻字されるのは既知の制限)
- 「十二時五十六秒」のような分を飛ばした秒指定(分または半の後にのみ秒を解釈)
- Date/Wareki::Date#strftime での %JT 解釈(時刻情報を持たないためリテラルのまま)
- DateTime.parse の返り値クラスの問題など、既存の DateTime.parse の挙動には手を入れない

## 設計方針

パース側は「純粋な翻字」に徹する: 日本語時刻表記を等価な ASCII 表記
(`HH:MM(:SS)`)に置換してから Ruby 標準パーサへ委ねる。値の範囲チェックは行わず、
「二十五時」→ `"25:00"` → Time.parse が ArgumentError (hour out of range)、のように
ASCII 等価入力と完全に同じ挙動になる。これは日・月の超過を InvalidDate
(< ArgumentError)とする既存方針とも整合する。

フォーマット側は既存の `Wareki::Date#expand_wareki_format`(%J 日付トークン展開)を
共用し、%JT 時刻トークン展開のみ新設する。

新規ファイル・新規 require は追加しない(`time` ライブラリへの依存も発生しない。
Time.parse 対応は Date._parse フック経由のため、利用者が `require 'time'` した
ときに自動的に有効になる)。

## パース仕様

### TIME_REGEX / TIME_PARSE_QUICK_FILTER (common.rb)

既存 `REGEX` と同様に `NUM_CHARS` を用いる。成分間の空白(`[[:space:]]`)は許容する。

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

- `正午` を最上位の選択肢に置く。「午後正午」のような表記は「午後」が残骸として
  残るだけで、既存のパース同様ゴミとして許容される(厳密に拒否しない)。
- `hour` の文字クラスに `正` `元` は含めない(日付専用の特殊表記のため)。
- TIME_REGEX は必ず非空マッチになる(hour+時 か 正午 が必須)。

### Utils.normalize_time(str)

文字列中の最初の TIME_REGEX マッチを `HH:MM(:SS)` に置換して返す。
TIME_PARSE_QUICK_FILTER に一致しない文字列は入力オブジェクトをそのまま返す
(非 String 入力を破壊しないため。フォールバック先の標準パーサに元のオブジェクトが
渡る挙動を保存する)。

変換規則:

1. 数値変換は既存 `Utils.k2i`(= ya_kansuji)を使用
2. `正午` → `12:00`
3. `午後` かつ 時 < 12 → 時 + 12(午後三時 → 15:00、午後12時 → 12:00)
4. `午前` は無変換(午前0時 → 00:00、午前12時 → 12:00)
5. `半` → 分 = 30
6. 分・秒が無い場合は 0 を補う。秒が無ければ `HH:MM` 形式で出力
7. 各数値は `%02d` で整形。範囲チェックは行わない(25時 → `"25:00"` のまま出力し、
   エラーにするかどうかは Ruby 標準側の判断に委ねる)

例(プロトタイプ検証済み):

| 入力 | 置換結果 |
|---|---|
| 十二時三十四分五十六秒 | 12:34:56 |
| １２時３４分 | 12:34 |
| 12時34分56秒 | 12:34:56 |
| 三時半 | 03:30 |
| 午後三時 | 15:00 |
| 午前十時 五分 | 10:05 |
| 正午 | 12:00 |
| 零時 | 00:00 |
| 二十五時 | 25:00 (→ Time.parse で ArgumentError) |
| 三時と五時 | 03:00と五時 (最初のみ置換) |
| 明治時代 | 変更なし |
| 平成元年5月4日 (時刻なし) | 変更なし(同一オブジェクト) |

### Date._parse / Date.parse フックへの組み込み (std_ext.rb)

両オーバーライドの先頭で `Utils.normalize_time` を通す。既存の
`PARSE_QUICK_FILTER` チェックより前に行う(時刻のみの文字列は年月日を含まないため)。

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

これだけで `Time.parse` / `Date._parse` が一括で対応される。`Date.parse` も
正規化することで、`Date.parse("12時34分")` が bogus な日付(当月12日)を返す
既存の誤解釈が ASCII `"12:34"` と同じ ArgumentError に揃う。
時刻表記は既存の和暦 REGEX にマッチしないため、`Wareki::Date._parse` の挙動には
影響しない。

## フォーマット仕様

### 追加フォーマット指示子

時刻系は `T` で名前空間化し、標準 strftime の H/M/S の文字を維持する。
半角数字の時分秒は標準の `%H` `%M` `%S` で出力できるため、単体指示子は
全角・漢数字のみを提供する。

| 指示子 | 出力 | 例 (12:34:56) |
|---|---|---|
| %JTf | 半角複合 "%02d時%02d分%02d秒" | 12時34分56秒 |
| %JTF | 漢数字複合 | 十二時三十四分五十六秒 |
| %JTH | 全角の時 | １２ |
| %JTHk | 漢数字の時 | 十二 |
| %JTM | 全角の分 | ３４ |
| %JTMk | 漢数字の分 | 三十四 |
| %JTS | 全角の秒 | ５６ |
| %JTSk | 漢数字の秒 | 五十六 |

- `%JTf` は既存 `%Jf` と同じくデフォルト 0 埋め。`%J-Tf` のように既存のフラグ
  構文(`%J` とキーの間)で制御できる
- 全角はパディングなし(既存 `%JS` 等と同じ)
- 漢数字は ya_kansuji の `:simple` スタイル(既存 `%JDk` 等と同じ)
- 複合指示子は秒が 0 でも常に3成分を出力する(00:00:00 → 零時零分零秒)
- 12時間制での出力(午前/午後の付与)は提供しない
- `%%JT...` のようにエスケープされた場合は展開しない(既存
  `FORMAT_EXPANSION_REGEX` と同じ `(?<!%)(?:%%)*\K` パターンを踏襲)

### 実装構造

1. **Utils.number_format(opt)** を新設: `Wareki::Date#_number_format` の本体を
   Utils へ移し、`Wareki::Date#_number_format` は `Utils.number_format` への
   委譲にする(%JTf のフラグ処理で共用するため)。

2. **Utils.expand_time_format(format_str, time)** を新設: `hour` / `min` / `sec`
   に応答するオブジェクト(Time / DateTime)を受け、%JT トークンを展開した文字列を
   返す。未知のキーはマッチさせずそのまま残す(既存の展開と同じ方針)。
   正規表現は Utils 配下の定数として定義する:

```ruby
TIME_FORMAT_DIRECTIVE_REGEX = /%J(-|[_0]{0,2}[0-9]*|)(T(?:[fF]|[HMS]k?))/.freeze
TIME_FORMAT_EXPANSION_REGEX = /(?<!%)(?:%%)*\K#{TIME_FORMAT_DIRECTIVE_REGEX}/.freeze
```

3. **StdExt** にヘルパを追加:

```ruby
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
```

4. **std_ext.rb** の Time / DateTime パッチ:

```ruby
class Time
  def to_wareki_date
    Wareki::Date.jd(to_date.jd)
  end

  alias _wareki_strftime_orig strftime
  def strftime(format)
    _wareki_strftime_orig(Wareki::StdExt.expand_all_wareki_formats(format, self))
  end
end

class DateTime
  alias _wareki_strftime_orig strftime
  def strftime(format = '%FT%T%:z')
    _wareki_strftime_orig(Wareki::StdExt.expand_all_wareki_formats(format, self))
  end
end
```

- 展開順は %JT → %J 日付系(キー文字クラスが互いに素なため順序依存はないが、
  展開結果に指示子が混入しない順とする)
- 標準トークン(%H %M %S など)は展開後の文字列ごと元の strftime に渡り、
  Time / DateTime 自身の時刻で解決される
- DateTime のデフォルトフォーマットは標準と同じ `'%FT%T%:z'` を維持する
- Date#strftime は変更しない(%JT はリテラルのまま。時刻情報を持たないため)

### エラー挙動

- %J 日付指示子を含むフォーマットで元号範囲外の日時(大化以前)の場合、既存の
  Date と同様に `Wareki::UnsupportedDateRange` が上がる(to_wareki_date 経由)。
  %JT のみのフォーマットでは wareki 日付変換自体が走らないため上がらない
- %J も %JT も含まなければ従来どおり(例外なし)

## 互換性への影響

いずれも不具合修正の扱いとし、2.0.0 リリースに含める:

1. `Date._parse("12時34分56秒")` の結果が `{mday: 12}` から
   `{hour: 12, min: 34, sec: 56}` に変わる
2. `Date.parse("12時34分")` が当月12日の日付ではなく ArgumentError になる
   (ASCII `"12:34"` と同じ)
3. `Time.parse("平成元年5月4日 二十五時")` は従来 00:00:00 として通っていたが、
   ArgumentError (hour out of range) になる(ASCII の `"25:00"` と同じ挙動。
   承認済みの線引き)
4. 既存の Date の挙動・%J 指示子はすべて不変

## テスト計画

- `spec/utils_spec.rb`:
  - `normalize_time`: 上記変換例の全パターン、空白許容、時刻なし文字列の素通し
    (同一オブジェクト)、複数時刻表記時は最初のみ置換されること
  - `expand_time_format`: 各トークン、フラグ付き `%J-Tf`、0秒時の複合出力、
    `%%JT` エスケープの素通し、未知キー(%JTz)の素通し
- `spec/std_ext_spec.rb`:
  - `Date._parse`: 和暦日付+漢数字時刻、時刻のみ、午前/午後、半、正午の各ハッシュ
  - `Time.parse`: ASCII 等価入力との一致、範囲外(二十五時)での ArgumentError
  - `Time#strftime`: `%JF %JTF` 複合、%JTf のパディング、標準指示子のみの従来動作、
    `%%JT` エスケープ、`Time#to_wareki_date`
  - `DateTime#strftime`: %JT 系、引数なしデフォルトが変わらないこと
  - `Date#strftime("%JTF")` がリテラルのまま返ること
- 既存スペック全体の回帰確認(`bundle exec rspec` + `bundle exec rubocop`)
- CI は ruby 2.7〜3.4 + head(gemspec は >= 2.0.0 のため保守的な構文を維持)

## ドキュメント更新

- README.md: 機能一覧に時刻対応を追記、使用例(Time.parse / %JT)、
  「追加フォーマット文字列一覧」に %JT 系を追加(Time / DateTime の strftime で
  のみ有効と注記)、制限事項に以下を明記:
  - 時刻は単純な数字変換のみ(和暦・十二時辰などとの対応なし)
  - 午前12時/午後12時は単純規則(午前はそのまま、午後は12時未満のみ+12)
  - 「三時間」のような時間量表現は時刻として解釈されうる
  - 範囲外の時刻(二十五時など)の可否は Ruby 標準の挙動に準拠(ArgumentError)
- ChangeLog の 2026-07-13 (2.0.0) エントリに追記
