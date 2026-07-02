# BLB安全リネームツール 仕様書

## 1. 基本方針

本仕様書は、`BLB安全リネームツール / BLB Safe Renamer` の実装仕様を定義する。

本ツールは、BATファイルを入口として実行し、内部でPowerShell 5系のスクリプトを呼び出す。

利用プログラミング言語は以下に限定する。

```text
PowerShell 5系
CMD
```

以下は使用しない。

```text
PowerShell 7以降専用機能
Python
Node.js
C#
外部ライブラリ
データベース
Webフレームワーク
```

---

## 2. システム構成

### 2.1 ファイル構成

初期版のファイル構成は以下とする。

```text
BLB-Safe-Renamer/
├─ README.md
├─ rename_map.txt
├─ run_precheck.bat
├─ run_execute.bat
├─ Rename-BlbSafe.ps1
├─ output/
└─ logs/
```

実運用時は、リネーム対象の `.blb` ファイルと同じフォルダに以下を配置する。

```text
対象フォルダ/
├─ f340.blb
├─ f341.blb
├─ f342.blb
├─ f30715.blb
├─ rename_map.txt
├─ run_precheck.bat
├─ run_execute.bat
├─ Rename-BlbSafe.ps1
├─ output/
└─ logs/
```

---

## 3. 各ファイルの役割

### 3.1 rename_map.txt

リネーム対応表を記載するファイル。

形式は以下とする。

```bat
ren "元ファイル名" "変換後ファイル名"
```

例：

```bat
ren "f340.blb" "Honbun2.txt"
ren "f341.blb" "Honbun3.txt"
ren "f342.blb" "Honbun8.txt"
ren "f30715.blb" "f30715.pdf"
```

---

### 3.2 run_precheck.bat

事前確認用BAT。

ファイル名変更は行わず、PowerShellスクリプトをDRYRUNモードで呼び出す。

---

### 3.3 run_execute.bat

本実行用BAT。

PowerShellスクリプトをEXECUTEモードで呼び出し、実際にファイル名変更を行う。

---

### 3.4 Rename-BlbSafe.ps1

リネーム処理本体。

主な処理は以下。

* 対応表読み込み
* 行パース
* 元ファイル存在チェック
* 変換後ファイル名チェック
* 重複判定
* 連番付与
* リネーム実行
* CSVログ出力

---

### 3.5 logsフォルダ

CSVログを格納するフォルダ。

存在しない場合はPowerShellスクリプト側で自動作成する。

---

## 4. 実行方式

### 4.1 事前確認

利用者は `run_precheck.bat` を右クリックし、管理者として実行する。

処理内容：

```text
ファイル名変更は行わない
rename_map.txt を読み込む
各行の妥当性を確認する
重複時の予定ファイル名を決定する
CSVログを出力する
```

---

### 4.2 本実行

利用者は `run_execute.bat` を右クリックし、管理者として実行する。

処理内容：

```text
rename_map.txt を読み込む
各行の妥当性を確認する
実際にファイル名を変更する
CSVログを出力する
```

---

## 5. BAT仕様

### 5.1 run_precheck.bat

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 > nul
cd /d "%~dp0"

echo BLB Safe Renamer - PreCheck
echo Current folder: %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Rename-BlbSafe.ps1" -ListPath "%~dp0rename_map.txt" -BaseDir "%~dp0"

echo.
echo PreCheck finished.
pause
```

---

### 5.2 run_execute.bat

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 > nul
cd /d "%~dp0"

echo BLB Safe Renamer - Execute
echo Current folder: %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Rename-BlbSafe.ps1" -ListPath "%~dp0rename_map.txt" -BaseDir "%~dp0" -Execute

echo.
echo Execute finished.
pause
```

---

## 6. PowerShellスクリプト仕様

### 6.1 ファイル名

```text
Rename-BlbSafe.ps1
```

---

### 6.2 対応PowerShellバージョン

```text
Windows PowerShell 5.x
```

PowerShell 7以降専用の構文や機能は使用しない。

---

### 6.3 パラメータ

| パラメータ    | 型      | 必須 | 内容                |
| -------- | ------ | -: | ----------------- |
| ListPath | string | 任意 | 対応表ファイルのパス        |
| BaseDir  | string | 任意 | 対象フォルダ            |
| Execute  | switch | 任意 | 指定時は本実行、未指定時は事前確認 |

---

### 6.4 実行例

事前確認：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Rename-BlbSafe.ps1" -ListPath ".\rename_map.txt" -BaseDir "."
```

本実行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Rename-BlbSafe.ps1" -ListPath ".\rename_map.txt" -BaseDir "." -Execute
```

---

## 7. 処理フロー

### 7.1 全体フロー

```text
開始
  ↓
BaseDirを確定
  ↓
logsフォルダ作成
  ↓
rename_map.txt存在確認
  ↓
対象フォルダ内の既存ファイル名を取得
  ↓
rename_map.txtを1行ずつ読み込み
  ↓
ren形式か判定
  ↓
元ファイル存在確認
  ↓
変換後ファイル名チェック
  ↓
重複確認
  ↓
必要に応じて連番付与
  ↓
DRYRUNの場合：ログのみ出力
EXECUTEの場合：Rename-Item実行
  ↓
CSVログ出力
  ↓
サマリー表示
  ↓
終了
```

---

## 8. 対応表パース仕様

### 8.1 有効行

以下の形式に一致する行のみ有効とする。

```bat
ren "source" "target"
```

正規表現イメージ：

```text
^\s*ren\s+"([^"]+)"\s+"([^"]+)"\s*$
```

### 8.2 無効行

以下はスキップ対象とする。

```text
空行
rem で始まるコメント行
:: で始まるコメント行
ren形式に一致しない行
```

無効行はCSVログに `SKIP_PARSE` として記録する。

---

## 9. リネーム仕様

### 9.1 基本リネーム

対応表が以下の場合、

```bat
ren "f340.blb" "Honbun2.txt"
```

実行結果は以下とする。

```text
f340.blb -> Honbun2.txt
```

---

### 9.2 拡張子変更

以下のように拡張子が変更される場合も、単純なファイル名変更として扱う。

```bat
ren "f30715.blb" "f30715.pdf"
ren "f50000.blb" "sample.TIF"
ren "f60000.blb" "data.txt"
```

本ツールではファイル内容の確認や変換は行わない。

---

### 9.3 重複時の連番付与

同じ変換後ファイル名が複数回指定された場合、2件目以降に `_002`, `_003` を付与する。

例：

```bat
ren "f340.blb" "Honbun2.txt"
ren "f11178.blb" "Honbun2.txt"
ren "f12000.blb" "Honbun2.txt"
```

実行結果：

```text
f340.blb    -> Honbun2.txt
f11178.blb -> Honbun2_002.txt
f12000.blb -> Honbun2_003.txt
```

---

### 9.4 拡張子付きファイルの連番仕様

拡張子の前に連番を付与する。

```text
Honbun2.txt
Honbun2_002.txt
Honbun2_003.txt
```

PDFの場合：

```text
Sample.PDF
Sample_002.PDF
Sample_003.PDF
```

TIFの場合：

```text
WF000113.TIF
WF000113_002.TIF
WF000113_003.TIF
```

---

### 9.5 既存ファイルとの衝突

対象フォルダにすでに変換後ファイル名が存在する場合、そのファイル名は使用済みとして扱う。

例：

```text
既存：Honbun2.txt
指定：Honbun2.txt
実際：Honbun2_002.txt
```

---

## 10. ファイル名チェック仕様

### 10.1 不正文字

変換後ファイル名に以下の文字が含まれる場合はエラー扱いとし、リネームしない。

```text
< > : " / \ | ? *
```

CSVログには `SKIP_INVALID_TARGET` として記録する。

---

### 10.2 末尾チェック

以下の場合は不正とする。

```text
ファイル名末尾が半角スペース
ファイル名末尾がピリオド
```

---

### 10.3 予約名チェック

以下のWindows予約名は不正とする。

```text
CON
PRN
AUX
NUL
COM1
COM2
COM3
COM4
COM5
COM6
COM7
COM8
COM9
LPT1
LPT2
LPT3
LPT4
LPT5
LPT6
LPT7
LPT8
LPT9
```

---

## 11. CSVログ仕様

### 11.1 出力先

```text
logs/rename_result_yyyyMMdd_HHmmss.csv
```

---

### 11.2 文字コード

CSVログの文字コードは以下とする。

```text
UTF-8
```

---

### 11.3 CSV項目

| 項目              | 内容               |
| --------------- | ---------------- |
| Time            | 処理日時             |
| Mode            | DRYRUN / EXECUTE |
| LineNo          | 対応表の行番号          |
| Status          | 処理ステータス          |
| Source          | 元ファイル名           |
| TargetRequested | 対応表上の変換後ファイル名    |
| TargetActual    | 実際に採用された変換後ファイル名 |
| Reason          | 補足理由             |
| Error           | エラー内容            |

---

### 11.4 ステータス一覧

| Status                | 内容            |
| --------------------- | ------------- |
| DRYRUN_OK             | 事前確認で問題なし     |
| OK                    | 本実行でリネーム成功    |
| SKIP_PARSE            | 対応表の行形式が不正    |
| SKIP_SOURCE_MISSING   | 元ファイルが存在しない   |
| SKIP_INVALID_TARGET   | 変換後ファイル名が不正   |
| SKIP_DUPLICATE_SOURCE | 同じ元ファイルが複数回登場 |
| ERROR_RENAME_FAILED   | リネーム処理に失敗     |

---

### 11.5 Reason例

| Reason                                             | 内容            |
| -------------------------------------------------- | ------------- |
| target duplicated; numbered filename assigned      | 重複により連番名を採用   |
| source file not found                              | 元ファイルが存在しない   |
| target filename contains invalid Windows character | ファイル名に不正文字あり  |
| same source file appears multiple times            | 同じ元ファイルが複数回登場 |
| line is not simple ren format                      | 対応表の行形式が不正    |

---

## 12. エラー処理仕様

### 12.1 元ファイルがない場合

処理をスキップし、CSVログに記録する。

```text
Status: SKIP_SOURCE_MISSING
```

---

### 12.2 変換後ファイル名が不正な場合

処理をスキップし、CSVログに記録する。

```text
Status: SKIP_INVALID_TARGET
```

---

### 12.3 同じ元ファイルが複数回指定された場合

2回目以降はスキップする。

```text
Status: SKIP_DUPLICATE_SOURCE
```

---

### 12.4 リネーム実行時に失敗した場合

例外内容をCSVログの `Error` に記録する。

```text
Status: ERROR_RENAME_FAILED
```

---

## 13. 画面表示仕様

BAT実行中のコンソールには以下を表示する。

```text
BLB Safe Renamer - PreCheck
Current folder: C:\Work\TargetFolder

Mode: DRYRUN
BaseDir: C:\Work\TargetFolder
ListPath: C:\Work\TargetFolder\rename_map.txt
LogPath: C:\Work\TargetFolder\logs\rename_result_20260702_093000.csv

Summary:
Name                    Count
----                    -----
DRYRUN_OK               27000
SKIP_SOURCE_MISSING      800
SKIP_INVALID_TARGET       10
SKIP_PARSE                 5

Finished.
```

本実行時は以下のように表示する。

```text
Mode: EXECUTE
```

---

## 14. 管理者実行時の仕様

BATファイルは、管理者として実行されることを想定する。

管理者実行時、カレントフォルダが以下になる場合がある。

```text
C:\Windows\System32
```

そのため、BATの先頭で必ず以下を実行する。

```bat
cd /d "%~dp0"
```

これにより、BATファイルが配置されたフォルダに移動してから処理する。

---

## 15. 実装上の注意事項

### 15.1 PowerShell 5系対応

PowerShell 7専用構文は使用しない。

使用可能な代表的コマンド：

```powershell
Get-Content
Test-Path
Join-Path
Resolve-Path
Get-ChildItem
Rename-Item
Export-Csv
New-Item
Group-Object
Sort-Object
Select-Object
```

---

### 15.2 文字コード

BATでは以下を指定する。

```bat
chcp 65001 > nul
```

PowerShellではUTF-8として読み込む。

```powershell
Get-Content -Encoding UTF8
Export-Csv -Encoding UTF8
```

---

### 15.3 同一フォルダ処理

初期版では、リネーム対象は同一フォルダ内のファイルのみとする。

サブフォルダ配下のファイルは対象外とする。

---

### 15.4 ファイル内容確認なし

本ツールは以下を行わない。

```text
PDF判定
TXT判定
画像判定
OCR
ファイルヘッダ確認
中身によるファイル名決定
```

対応表に記載されたファイル名を正として扱う。

---

## 16. 受入条件

以下を満たした場合、初期版を受入可能とする。

| No | 条件                         | 判定 |
| -: | -------------------------- | -- |
|  1 | BATからPowerShellを呼び出せる      | 必須 |
|  2 | 事前確認モードでファイル名変更されない        | 必須 |
|  3 | 本実行モードでリネームされる             | 必須 |
|  4 | 重複時に `_002`, `_003` が付与される | 必須 |
|  5 | CSVログが出力される                | 必須 |
|  6 | 元ファイルなしがログに記録される           | 必須 |
|  7 | 不正ファイル名がログに記録される           | 必須 |
|  8 | 管理者実行でも対象フォルダを正しく認識する      | 必須 |
|  9 | PowerShell 5系で動作する         | 必須 |
| 10 | CMDとPowerShell以外を使用しない     | 必須 |

---

## 17. テスト観点

### 17.1 正常系

```text
ren "f340.blb" "Honbun2.txt"
```

期待結果：

```text
f340.blb が Honbun2.txt に変更される
CSVログに OK が出力される
```

---

### 17.2 重複系

```bat
ren "f340.blb" "Honbun2.txt"
ren "f341.blb" "Honbun2.txt"
```

期待結果：

```text
f340.blb -> Honbun2.txt
f341.blb -> Honbun2_002.txt
```

---

### 17.3 元ファイルなし

```bat
ren "notfound.blb" "sample.txt"
```

期待結果：

```text
SKIP_SOURCE_MISSING
```

---

### 17.4 不正ファイル名

```bat
ren "f340.blb" "A:B.txt"
```

期待結果：

```text
SKIP_INVALID_TARGET
```

---

### 17.5 拡張子変更

```bat
ren "f30715.blb" "f30715.pdf"
```

期待結果：

```text
f30715.blb -> f30715.pdf
```

---

### 17.6 既存ファイル衝突

対象フォルダにすでに以下が存在する。

```text
Honbun2.txt
```

対応表：

```bat
ren "f340.blb" "Honbun2.txt"
```

期待結果：

```text
f340.blb -> Honbun2_002.txt
```

---

## 18. README記載事項

READMEには以下を記載する。

```text
概要
前提条件
ファイル構成
使い方
事前確認方法
本実行方法
対応表の書き方
CSVログの見方
注意事項
よくあるエラー
```

---

## 19. 初期実装対象ファイル

初期実装で作成するファイルは以下とする。

```text
README.md
rename_map.txt
run_precheck.bat
run_execute.bat
Rename-BlbSafe.ps1
```

---

## 20. 運用時の注意

本実行前に、対象フォルダ全体のバックアップを取得することを推奨する。

特に28,000件規模の大量リネームでは、実行後の手戻りが難しいため、以下の順序を必須運用とする。

```text
1. バックアップ取得
2. 事前確認
3. CSVログ確認
4. 本実行
5. 実行後CSVログ確認
6. ログ保管
```

---

## 21. 初期版の完成基準

初期版は以下を満たすことで完成とする。

```text
PowerShell 5系で動作する
BATから呼び出せる
事前確認と本実行を分離できる
28,000件程度の対応表を処理できる
重複時に連番を付けられる
CSVログを出力できる
ファイル内容確認を行わない
外部ライブラリを使用しない
```

