# wareki - ruby 和暦ライブラリ

[<img src="https://badge.fury.io/rb/wareki.svg" alt="Gem Version" />](https://badge.fury.io/rb/wareki)
[<img src="https://github.com/sugi/wareki/actions/workflows/ci.yml/badge.svg" alt="Build Status" />](https://github.com/sugi/wareki/actions/workflows/ci.yml)
[<img src="https://coveralls.io/repos/sugi/wareki/badge.svg?branch=master&service=github" alt="Coverage Status" />](https://coveralls.io/github/sugi/wareki?branch=master)
[<img src="https://api.codeclimate.com/v1/badges/c9209422700b526d2b45/maintainability" />](https://codeclimate.com/github/sugi/wareki/maintainability)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a5e0b6022b6d485b86a195be7a392da5)](https://app.codacy.com/gh/sugi/wareki/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

## 概要

日本の和暦をサポートするライブラリです。
旧暦は445年から、元号は大化から全て処理できます。
元号はWikipedia、暦は日本暦日原典由来のデータを元にしています。

## 機能

* 和暦文字列のパース
  * 旧字体、１文字元号のサポート (慶應、萬延、㍻ など)
  * 全角数字、漢数字、全角ゼロ、大字のサポート (１０月、十月、一〇月、拾月、什月)
  * 閏月サポート
  * 月の別名のサポート (如月、弥生、師走など)
  * 元年、正月、朔日、晦日、廿一日、卅日 などの特殊な表記の日付サポート
* Date クラスの拡張
  * 標準の strftime に和暦へのフォーマット文字列を追加
  * to_wareki_date を追加
  * Date::JAPAN (明治改暦日)の追加

## インストール

Gemfile に以下のようにするか、

```ruby
gem 'wareki'
```

もしくは、直接 gem install して下さい。

```
gem install wareki
```

## 使い方の例

### ありそうな例

```ruby
require 'wareki'

d = Date.parse("平成二七年 08月 ２２日")
d.strftime("%F")   # => "2015-08-22"
d.strftime("%JF")  # => "平成二十七年八月二十二日"
d.strftime("%Jf")  # => "平成27年8月22日"
```

### パース

旧暦を含むの日本語の日付文字列パースして、組み込み Date オブジェクトに変換できます。この時、慣例的に使われていたい色々な表記も解釈できます。(標準では Date::ITALY な Date オブジェクトに変換しますが、必要であれば第3引数の start に改暦日を渡せます。)

```ruby
# 和暦のパース (標準 Date インスタンス)
Date.parse("㍻一〇年 肆月 晦日")       # => #<Date: 1998-04-30 ...
Date.parse("安政七年 弥生")           # => #<Date: 1860-03-22 ...
Date.parse("元仁元年閏七月朔日")       # => #<Date: 1224-08-17 ...
Date.parse("萬延三年 ５月 廿一日")     # => #<Date: 1862-06-18 ...
Date.parse("皇紀二千皕卌年")          # => #<Date: 1580-01-17 ...
Date.parse("正嘉元年 うるう3月 １２日") # => #<Date: 1257-04-27 ...

# Wareki::Date を直接扱う場合
Date.today.to_wareki_date # => Wareki::Date インスタンス
Wareki::Date.parse("正嘉元年 うるう3月 １２日") # => Wareki::Date インスタンス
Wareki::Date.new("明治", 8, 2, 1).to_date   # => 標準 Date インスタンス 1875-02-01
```

### 和暦・旧暦へのフォーマット

日本では明治5年まで、グレゴリオ暦でもユリウス歴でもない旧暦が使われていました。これもフォーマット文字列経由で透過的に扱えます。

```ruby
Date.today.strftime("%JF")              # => "平成二十七年八月二十二日"
Date.civil(1311, 7, 20).strftime("%JF") # => "応長元年閏六月四日"
```

旧暦の場合の月日 (%Jm, %Jd) と、グレゴリオ暦やユリウス暦での月日 (%m, %d)は違うものを出力します。

```ruby
d = Date.civil(1860, 4, 7)
dj = d.new_start(Date::JULIAN)
d.strftime                     # => "1860-04-07" (グレゴリオ暦)
dj.strftime                    # => "1860-03-26" (ユリウス暦)
d.strftime("%Jf")              # => "安政7年3月17日" (日本の旧暦)
d.strftime("皇紀%Ji年%Jm月%Jd日") # => "皇紀2520年3月17日" (日本の旧暦で神武天皇即位紀元年)
```

### Rails I18n から使う場合

strftime が拡張されるので、 `config/locale/ja.yml` にそのままフォーマット文字列が指定できます。例えば

```yaml
  ja:
    date:
      formats:
        default: "%JF"
```

の様にすると、 I18n.l (I18n.localize) の出力が標準で和暦日本語になります。
標準は変更せず、特定の箇所で使い分けたい場合は、例えば、

```yaml
  ja:
    date:
      formats:
        ja_kan: "%JF"
```

の様に別のフォーマットキーを設定して、以下のように呼び出し時に `format` に指定します。

```erb
  <%= I18n.l Date.today, format: :ja_kan %>
```

## 追加フォーマット文字列一覧

通常の strftime のフォーマット文字列に **加えて**、 以下が使用できます。これ以外のフォーマット文字列に関しては、そのまま strftime へ引き渡され、プラットフォーム依存で解決されます。

* %Jf: "%Je%Jg年%Js%Jl月%Jd日" の略 (例: 平成23年3月12日)
* %JF: "%Je%JGK年%JLk%JSk月%JDk日" の略 (例: 平成二十三年三月十二日)
* %Jy: "%Je%Jg" の略 (元号+半角数字年)
* %JY: "%Je%JG" の略 (元号+全角数字年)
* %JYk: "%Je%Gk" の略 (元号+漢数字年)
* %JYK: "%Je%GK" の略 (元号+特殊漢数字年)
* %Je: 元号 (存在しない場合空文字列になります)
* %Jg: 和暦年の半角数字（元号が存在しない場合空文字列）
* %JG: 和暦年の全角数字（元号が存在しない場合空文字列）
* %JGk: 和暦年の漢数字（元号が存在しない場合空文字列）
* %JGK: 和暦年の漢数字の特殊記法 (元) （元号が存在しない場合空文字列）
* %Jo: 旧暦年の半角数字
* %JO: 旧暦年の全角数字
* %JOk: 旧暦年の漢数字
* %Ji: 神武天皇即位紀元(皇紀)年の半角数字
* %JI: 神武天皇即位紀元(皇紀)年の全角数字
* %JIk: 神武天皇即位紀元(皇紀)年の漢数字
* %Jm: "%Js%Jl" の略 (和暦月の半角数字。閏月は後ろに "'" を追加)
* %JM: "%JLk%JS" の略 (和暦月の全角数字。閏月は前に "閏" を追加)
* %JMk: "%JLk%JSk" の略 (和暦月の漢数字。閏月は前に "閏" を追加)
* %Js: 和暦月の半角数字
* %JS: 和暦月の全角数字
* %JSk: 和暦月の漢数字
* %JSK: 和暦月の別名 (睦月、如月、弥生...)
* %Jl: 和暦月が閏月の場合 "'"、そうでなければ空文字列になります。
* %JL: 和暦月が閏月の場合 "’"、そうでなければ空文字列になります。
* %JLk: 和暦月が閏月の場合 "閏"、そうでなければ空文字列になります。
* %Jd: 和暦日の半角数字
* %JD: 和暦日の全角数字
* %JDk: 和暦日の漢数字
* %JDK: 和暦日の漢数字の特殊記法 (朔、晦)

## 仕様、限界、制限など

* 作者は暦の専門家ではまったくありません。ツッコミお待ちしています。
* 皇紀と旧暦が出力できますが、旧暦445年1月1日(先発グレゴリオ暦で445年1月25日)より前の日付はサポートしていません。扱おうとすると Wareki::UnsupportedDateRange 例外を上げます。
* また Date 型からの変換の場合、 現状「大化」で1年1月1日扱いになる日(ユリウス暦で645年2月2日、先発グレゴリオ暦では645年2月5日)より前の日付はサポートしていません。こちらも Wareki::UnsupportedDateRange 例外がおきます。
* 日本暦日原典の対照表が、どの暦法を元にしているのか分かっていません。単にデータだけを利用しています。
* 内部的には全てユリウス日を経由して変換しています。
* パース時には元号の存在しない年(例: 霊亀百年)を受け入れます。しかし現状、Date に変換した場合この情報は捨てられ、パース時の元号を復元することはできません。(Wareki::Date を直接扱えば可能です)
* 改暦による存在しない日(明治5年12月3日〜31日)は基本的に例外(ArgumentError)を上げます。が、現状このチェックは完全ではありません。
* 北朝の元号も解釈できます。しかし現在の所、北朝の元号で文字列にフォーマットすることはできません。
* 10月の別名は「神無月」しかサポートしていません
* 将来の日付に関しては、現在の元号がずっと継続しているとみなします
* 日本でユリウス暦は使われていないので、Date::JAPAN は単にグレゴリオ暦への改暦日の目安、と言うだけです。Date.new で使う意味はほぼありません。

## 参照元データ

作成には以下のデータを参照しました。

* Wakaba 氏による https://github.com/manakai/data-locale のデータを利用しています
  * 旧暦: [suikawiki - 旧暦](http://wiki.suikawiki.org/n/%E6%97%A7%E6%9A%A6#section-%E5%AF%BE%E7%85%A7%E8%A1%A8%E3%81%A8%E5%A4%89%E6%8F%9B%E3%83%84%E3%83%BC%E3%83%AB) にある「日本暦日原典」第4版準拠の先発グレゴリオ暦対照表
* 元号: [Wikipedia - 元号一覧_(日本)](https://ja.wikipedia.org/wiki/%E5%85%83%E5%8F%B7%E4%B8%80%E8%A6%A7_%28%E6%97%A5%E6%9C%AC%29) のユリウス歴とグレゴリオ暦表記の物に基づいています

## ライセンス

[The BSD 2-Clause License](https://opensource.org/licenses/BSD-2-Clause)

## 作者

Tatsuki Sugiura <sugi@nemui.org>
