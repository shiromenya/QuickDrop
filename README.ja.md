# QuickDrop

[English README](README.md)

ファイルをドラッグしたときだけ画面の **上・左・右の3辺**（下辺を除く）がほのかに光り、そのままフチに触れてドロップするとファイルが画面外へ「ふわっ」と飛ぶアニメーションの後に macOS 純正の **AirDrop** 共有画面が開く、軽量な常駐型オープンソース Mac アプリです。

---

## 主な特長

- **下辺を除いた3辺だけ光るデザイン**
  - Dock がある下辺は光らず・反応しないため、普段の操作を邪魔しません。
  - ファイルをドラッグしている間だけ3辺がさりげなく発光し、フチに触れるとその辺が明るく反応して `AirDrop で送信`（または共有メニュー設定時は `共有メニューを開く`）バッジが表示されます。
  - フチにドロップした瞬間、ファイルのサムネイル（またはアイコン）が画面の外へ向かって「ふわっ」と吸い込まれていく演出とともに共有画面が開きます。
- **元のファイルは一切動かさない（最初の位置のまま）**
  - ドロップ時は常に非破壊の `.copy`（または `.generic`）として参照のみを受け取り、`.move` を返しません。
  - 元のファイルパスをそのまま共有サービスに渡すため、共有完了後（およびキャンセル時）もファイルはドラッグ開始前の場所・デスクトップ位置にそのまま残ります。
- **AirDrop 直接送信 / 共有メニュー / 辺ごとの割り当て ＆ 自動 ZIP 圧縮**
  - **直接 AirDrop**（`NSSharingService(named: .sendViaAirDrop)`）と **macOS 共有メニュー**（`NSSharingServicePicker`）を切り替えられるほか、**左・上・右の辺ごとに別の共有アクション**を割り当てられます。
  - 複数ファイルやフォルダ送信時の **自動 ZIP 圧縮**（`Shift` キーを押しながらドロップしてその場限りで ZIP 化も可能・送信後に一時 ZIP を自動削除）や、メニューバーの **最近の共有（直近5件・メモリ保持のみ）** からのワンクリック再送に対応しました。
  - エラーや AirDrop 利用不可時は、作業を遮るモーダルダイアログではなく、控えめなフローティングトースト HUD で案内します。
- **柔軟なマルチディスプレイ対応**
  - モニターを並べて使っている場合、隣り合うディスプレイ同士が接している境界の辺は自動的に除外します（画面間でファイルを移動する際の誤反応を防止／設定から切替可能）。
  - **「有効な全ディスプレイ」** と **「カーソルがある画面のみ」** の発光モード切替に加え、接続中のモニターごとの個別 ON/OFF にも対応しました。
- **誤爆対策と一時停止（スヌーズ）**
  - **誤接触ガード（ホバー反応待ち）**：フチに一瞬かすめただけで反応しないよう、`0秒` / `0.12秒` / `0.25秒` の反応待ち時間を設定できます。
  - **一時停止（30分 / 1時間）**：作業中だけ一時的にオフにしたいとき、メニューバーから 30 分または 1 時間だけスヌーズでき、いつでも即再開できます。
  - **修飾キーでの制御**：`常に有効` / `Option (⌥) 押下中は一時無効` / `Option (⌥) 押下中のみ有効` を切り替えできます。
  - **アプリごとの除外**：最前面のアプリ（Figma / Photoshop / ゲームなど）をメニューバーや設定画面からワンクリックで除外リストに追加・解除できます。
  - **反応する辺・フチ幅の調整**：左・上・右それぞれの個別 ON/OFF、四隅のホットコーナー回避、当たり判定幅（狭い `8pt` / 標準 `14pt` / 広い `24pt`）を選択可能です。
- **ネイティブ設定ウィンドウ（`⌘,`）・プレビュー発光・初回ガイド**
  - SwiftUI 製の設定ウィンドウから全項目を一覧でき、設定を変えながらすぐ見た目を確認できる **テスト発光（プレビュー）** ボタンや、初回起動時のウェルカムガイドを備えています。
  - macOS のシステム言語に応じた **日本語 / 英語** ローカライズ、および OS の **「視差効果を減らす（Reduce Motion）」** アクセシビリティ設定にも対応しています。
- **フィードバック・更新確認・Web ドラッグ対応**
  - トラックパッド向けの触覚フィードバックに加え、ドロップ時の控えめな効果音（任意 ON/OFF）に対応しました。
  - GitHub Releases から最新版をチェックできる **アップデート確認機能**（起動時の自動チェック ON/OFF 可）と Homebrew Cask テンプレート（`packaging/homebrew/quickdrop.rb`）を同梱しています。
  - **Web 画像・URL ドラッグ対応（任意）**：デフォルトはファイル限定（誤爆防止）ですが、設定をオンにするとブラウザ上の画像やリンクのドラッグも AirDrop できます。
- **ログイン時に起動**
  - `.app` バンドル実行時はメニューバーからログイン時の自動起動を設定できます（`SMAppService.mainApp` 対応・システム設定への誘導付き）。

---

## 動作環境

- macOS 13.0 (Ventura) 以降
- ソースからビルドする場合：Xcode 15+ または Swift 5.9+

---

## ダウンロード後の初回起動（Gatekeeper 対策）

GitHub Releases 等で配布するアドホック署名版（Apple 公証なし）のバイナリは、初回起動時に macOS のセキュリティ警告（「開発元が未確認のため開けません」）が表示される場合があります。

1. `QuickDrop.app` を **アプリケーション** フォルダへ移動します。
2. `QuickDrop.app` を右クリック（または Control+クリック）して **開く** を選ぶか、**システム設定 ＞ プライバシーとセキュリティ ＞ このまま開く** をクリックします。
3. ターミナルを使う場合は検疫属性を解除できます：
   ```bash
   xattr -cr /Applications/QuickDrop.app
   ```

---

## ビルド・テスト・実行（macOS）

### 1. `.app` バンドルをビルドして起動する（おすすめ）

```bash
git clone https://github.com/shiromenya/QuickDrop.git
cd QuickDrop
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open build/QuickDrop.app
```

このスクリプトはリリースビルドに加え、`scripts/generate-icon.swift` と `iconutil` でアプリアイコン（`QuickDrop.icns`）を生成・同梱し、アドホック署名を付与した `build/QuickDrop.app` を作成します。

### 2. ユニットテスト・SwiftPM / Xcode での実行

```bash
# ユニットテストを実行
swift test

# ターミナルから直接実行
swift run

# Xcode で開く場合
open Package.swift
```

> **Note:** `swift run` で直接実行する場合は `.app` バンドルではないため、「ログイン時に起動」項目は無効表示になります。

---

## アーキテクチャ

```text
Sources/
├── QuickDrop/
│   └── QuickDropApp.swift                  # 最小の @main エントリポイント
└── QuickDropCore/
    ├── AppDelegate.swift                   # 全体制御・ディスプレイ変更監視・設定画面連携
    ├── Models/
    │   ├── ScreenEdge.swift                # 3辺座標計算・隣接ディスプレイ境界判定
    │   └── DraggedPayload.swift            # ペーストボード抽出（ファイル / 画像 / Web URL）
    ├── Services/
    │   ├── GlobalDragMonitor.swift         # NSEvent + NSPasteboard(.drag) + 修飾キー/除外アプリ判定
    │   ├── FilePreviewProvider.swift       # QuickLook サムネイル事前取得＋アイコン即時フォールバック
    │   ├── AirDropService.swift            # AirDrop 直接送信 / 共有メニュー起動＋一時PNG後始末
    │   ├── ZipArchiver.swift               # ditto を使った非破壊の一時 ZIP 圧縮
    │   ├── RecentShareHistory.swift        # メモリ上の直近共有履歴（再送用）
    │   ├── UpdateChecker.swift             # GitHub Releases バージョン確認・セマンティックバージョン比較
    │   └── QuickDropSettings.swift         # UserDefaults / スヌーズ / ディスプレイ設定 / SMAppService 管理
    ├── UI/
    │   ├── EdgeGlowView.swift              # 3辺発光＋ふわっとアニメーション（視差効果低減対応）
    │   ├── EdgeDropPanel.swift             # 画面端ドロップ受け皿（.move 非許可・誤接触ガード対応）
    │   ├── EdgeOverlayCoordinator.swift    # カーソル画面追従・テスト発光・触覚/効果音制御
    │   ├── MenuBarController.swift         # メニューバー UI（スヌーズ・ディスプレイ・アプリ除外等）
    │   ├── OnboardingView.swift            # 初回起動ウェルカムガイド
    │   ├── SettingsView.swift              # SwiftUI 製ネイティブ設定ウィンドウ（⌘,）
    │   └── ToastHUDWindow.swift            # 作業を遮らないフローティングトースト HUD
    ├── Utilities/
    │   └── L10n.swift                      # 多言語リソースバンドル解決（EN / JA）
    └── Resources/
        ├── en.lproj/Localizable.strings    # 英語 UI 文字列
        └── ja.lproj/Localizable.strings    # 日本語 UI 文字列
```
<!-- Homebrew Cask 用テンプレートは packaging/homebrew/quickdrop.rb に配置 -->

---

## ライセンス

[MIT License](LICENSE)
