# Time.parse / Time#strftime 漢数字時刻サポート 設計書

日付: 2026-07-13
ステータス: 承認済み(実装前)

## 背景と目的

wareki は現状 Date.parse / Date#strftime のみを拡張している。これに加え、時刻の
日本語表記(漢数字・全角数字の時分秒)のパースとフォーマットをサポートする。
時刻には元号のようなマッピングは存在しないため、単純な数字変換に徹する。

事前調査で判明している現状:

- `Time.parse` は内部で `Date._parse` を呼ぶため、`Time.parse("平成元年5月4日 12:34:56")`
  は現状でも動作する。対応すべきは漢数字時刻の解釈である。
- `Date._parse("12時34分56秒")` は Ruby 標準パーサが `{mday: 12}` と誤解釈する。
- DateTime は Date と別に自前の strftime を定義しているため、wareki の %J 拡張が
  DateTime では一切効いていない(`"%JF"` がリテラルのまま返る)。
- 既存 `%Jf` の数値はデフォルト `%02d` パディングで、`%J-f` 等のフラグで制御できる。

## スコープ

対応する:

- 漢数字・全角数字・半角数字 + 時/分/秒 のパース(例: 十二時三十四分五十六秒、１２時３４分)
- 午前/午後(午後三時 → 15:00)
- 「半」(三時半 → 3:30)
- 「正午」(→ 12:00。零時・〇時は数字として自然に解釈されるため特別扱い不要)
- Time#strftime / DateTime#strftime への %J(日付系・既存)と %JT(時刻系・新設)対応
- DateTime#strftime で %J が効いていない既存不具合の修正

対応しない:

- `Time.strptime`(フォーマット指示子によるパース側の対応)
- `Wareki::Date` への時刻情報の保持(Wareki::Time のような値オブジェクトも作らない)
- 「三時間」のような時間量表現(「三時」部分が時刻として翻字されるのは既知の制限)
- 「十二時五十六秒」のような分を飛ばした秒指定(分または半の後にのみ秒を解釈)
- Date/Wareki::Date#strftime での %JT 解釈(時刻情報を持たないためリテラルのまま)

## 設計方針

パース側は「純粋な翻字」に徹する: 日本語時刻表記を等価な ASCII 表記
(`HH:MM(:SS)`)に置換してから Ruby 標準パーサへ委ねる。値の範囲チェックは行わず、
「二十五時」→ `"25:00"` → Time.parse が ArgumentError、のように ASCII 等価入力と
完全に同じ挙動になる。これは日・月の超過を invalid date(ArgumentError)とする
既存方針とも整合する。

フォーマット側は Wareki::Date#strftime の %J 展開ロジックを「トークン展開のみを
行い文字列を返す」メソッドに切り出し、Time / DateTime のオーバーライドから共用する。

新規ファイル・新規 require は追加しない(`time` ライブラリへの依存も発生しない。
Time.parse 対応は Date._parse フック経由のため、利用者が `require 'time'` した
ときに自動的に有効になる)。

## パース仕様

### TIME_REGEX (common.rb)

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
```

- `正午` を最上位の選択肢に置く。「午後正午」のような表記は「午後」が残骸として
  残るだけで、既存のパース同様ゴミとして許容される(厳密に拒否しない)。
- `hour` の文字クラスに `正` `元` は含めない(日付専用の特殊表記のため)。

### Utils.normalize_time(str)

文字列中の最初の TIME_REGEX マッチ(非空)を `HH:MM(:SS)` に置換して返す。
マッチしなければ元の文字列をそのまま返す。

変換規則:

1. 数値変換は既存 `Utils.k2i`(= ya_kansuji)を使用
2. `正午` → `12:00`
3. `午後` かつ 時 < 12 → 時 + 12(午後三時 → 15:00、午後12時 → 12:00)
4. `午前` は無変換(午前0時 → 00:00、午前12時 → 12:00)
5. `半` → 分 = 30
6. 分・秒が無い場合は 0 を補う。秒が無ければ `HH:MM` 形式で出力
7. 各数値は `%02d` で整形。範囲チェックは行わない(25時 → `"25:00"` のまま出力し、
   エラーにするかどうかは Ruby 標準側の判断に委ねる)

例:

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
| 平成元年5月4日 (時刻なし) | 変更なし |

### Date._parse フックへの組み込み (std_ext.rb)

既存の `Date._parse` オーバーライドの先頭で `Utils.normalize_time` を通す。
和暦日付が見つからず標準パーサへフォールバックする経路でも、正規化済み文字列を
渡す(時刻のみの文字列に対応するため)。

```ruby
def _parse(str, comp = true)
  str = Wareki::Utils.normalize_time(str)
  di = Wareki::Date._parse(str)
  wdate = Wareki::Date.new(di[:era], di[:year], di[:month], di[:day], di[:is_leap])
rescue ArgumentError, Wareki::UnsupportedDateRange
  ::Date._wareki__parse_orig(str, comp)
else
  ::Date._wareki__parse_orig(str.sub(Wareki::REGEX, wdate.strftime('%F ')), comp)
end
```

これだけで `Time.parse` / `DateTime.parse` / `Date._parse` が一括で対応される。
`Date.parse` のオーバーライド(`Wareki::Date.parse` 経由)は時刻を扱わないため変更しない。
時刻表記は既存の和暦 REGEX にマッチしないため、`Wareki::Date._parse` の挙動にも影響しない。

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

### 実装構造

1. **Wareki::Date#expand_format(format_str)** を新設(リファクタリング):
   既存 `#strftime` 内の %J 展開 gsub をそのまま切り出し、展開後の文字列を返す。
   `#strftime` はこれを呼んだ後、従来どおり残りを ::Date#strftime へ委譲する
   (外部挙動は不変)。

2. **Utils._number_format** へ移動: `Wareki::Date#_number_format` を Utils へ移し、
   Wareki::Date からは委譲で呼ぶ(%JTf のフラグ処理で共用するため)。

3. **Utils.expand_time_format(format_str, time)** を新設: `hour` / `min` / `sec`
   に応答するオブジェクト(Time / DateTime)を受け、%JT トークンを展開した文字列を
   返す。未知のキーはマッチさせずそのまま残す(既存の展開と同じ方針)。

4. **std_ext.rb** に以下を追加:

```ruby
class Time
  def to_wareki_date
    Wareki::Date.jd(to_date.jd)
  end

  alias _wareki_strftime_orig strftime
  def strftime(format)
    format.index('%J') or return _wareki_strftime_orig(format)
    ret = Wareki::Utils.expand_time_format(format, self)
    ret = to_wareki_date.expand_format(ret)
    _wareki_strftime_orig(ret)
  end
end

class DateTime
  alias _wareki_strftime_orig strftime
  def strftime(format = '%FT%T%:z')
    format.index('%J') or return _wareki_strftime_orig(format)
    ret = Wareki::Utils.expand_time_format(format, self)
    ret = to_wareki_date.expand_format(ret)
    _wareki_strftime_orig(ret)
  end
end
```

- 展開順は %JT → %J 日付系。キー文字クラスが互いに素なため順序依存はないが、
  日付展開後の文字列に標準トークンが残る前提で最後に元の strftime を呼ぶ
- `%J` を含まないフォーマットは即座に元の strftime へ委譲(オーバーヘッド最小化)
- DateTime のデフォルトフォーマットは標準と同じ `'%FT%T%:z'` を維持する
- Time#to_wareki_date は Date#to_wareki_date と対になる公開メソッドとして追加

### エラー挙動

- %J を含むフォーマットで元号範囲外の日時(大化以前)の場合、既存の Date と同様に
  `Wareki::UnsupportedDateRange` が上がる(to_wareki_date 経由)
- %J を含まなければ従来どおり(例外なし)

## 互換性への影響

いずれも不具合修正の扱いとし、2.0.0 リリースに含める:

1. `Date._parse("12時34分56秒")` の結果が `{mday: 12}` から
   `{hour: 12, min: 34, sec: 56}` に変わる
2. `DateTime#strftime` が %J を解釈するようになる(従来はリテラルのまま返っていた)
3. `Time.parse("平成元年5月4日 二十五時")` は従来 00:00:00 として通っていたが、
   ArgumentError になる(ASCII の `"25:00"` と同じ挙動。承認済みの線引き)
4. 既存の Date の挙動・%J 指示子はすべて不変

## テスト計画

- `spec/utils_spec.rb`:
  - `normalize_time`: 上記変換例の全パターン、空白許容、時刻なし文字列の素通し、
    複数時刻表記時は最初のみ置換されること
  - `expand_time_format`: 各トークン、フラグ付き `%J-Tf`、0秒時の複合出力、
    未知キーの素通し
- `spec/std_ext_spec.rb`:
  - `Time.parse`: 和暦日付+漢数字時刻、時刻のみ、午前/午後、半、正午、
    ASCII 等価入力との一致、範囲外(二十五時)での ArgumentError
  - `Time#strftime`: `%JF %JTF` 複合、%J なしフォーマットの従来動作
  - `DateTime#strftime`: `%JF` が効くこと(既存不具合の修正確認)、%JT 系、
    デフォルトフォーマットが変わらないこと
  - `Date._parse("12時34分56秒")` が時刻ハッシュを返すこと
- 既存スペック全体の回帰確認(`bundle exec rspec` + `rubocop`)
- CI は ruby 2.7〜3.4 + head(gemspec は >= 2.0.0 のため保守的な構文を維持)

## ドキュメント更新

- README.md: 機能一覧に時刻対応を追記、使用例(Time.parse / %JT)、
  「追加フォーマット文字列一覧」に %JT 系を追加、制限事項に以下を明記:
  - 時刻は単純な数字変換のみ(和暦・十二時辰などとの対応なし)
  - 午前12時/午後12時は単純規則(午前はそのまま、午後は12時未満のみ+12)
  - 「三時間」のような時間量表現は時刻として解釈されうる
- ChangeLog にエントリ追加
