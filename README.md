# Nittei

変則的な大学の時間割を、日付ベースでそのまま管理するためのiOS向けSwiftUIアプリです。

## 入っている機能

- 2026年4月から8月までの月間カレンダー表示
- 日付タップで、その日の予定を`何限`順に一覧表示
- `科目`と`場所`の登録
- `テストの日`を赤系で強調表示
- 右下ボタンからの簡単追加
- 端末内保存 `UserDefaults`

## 想定

- 繰り返し時間割ではなく、変則日程を日付ごとに積んでいく
- バックエンドなし
- まずはフロントエンドを素早く試す用途

## 開き方

```bash
xcodegen generate
open Nittei.xcodeproj
```

## ビルド確認

```bash
xcodebuild -project Nittei.xcodeproj -scheme Nittei -destination 'generic/platform=iOS Simulator' build
```
