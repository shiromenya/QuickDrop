# QuickDrop

[English README](README.md)

ファイルをドラッグしたときだけ画面の **上・左・右の3辺**（下辺を除く）がほのかに光り、そのままフチに触れてドロップするとファイルが画面外へ「ふわっ」と飛ぶアニメーションの後に macOS 純正の **AirDrop** 共有画面が開く、軽量な常駐型オープンソース Mac アプリです。

---

## 主な特長

- **下辺を除いた3辺だけ光るデザイン**
  - Dock がある下辺は光らず・反応しないため、普段の操作を邪魔しません。
  - ファイルをドラッグしている間だけ3辺がさりげなく発光し、フチに触れるとその辺が明るく反応して `AirDrop で送信` バッジが表示されます。
  - フチにドロップした瞬間、ファイルのサムネイル（またはアイコン）が画面の外へ向かって「ふわっ」と吸い込まれていく演出とともに AirDrop 画面が開きます。
- **元のファイルは一切動かさない（最初の位置のまま）**
  - ドロップ時は常に非破壊の `.copy`（または `.generic`）として参照のみを受け取り、`.move` を返しません。
  - 元のファイルパスをそのまま AirDrop に渡すため、共有完了後（およびキャンセル時）もファイルはドラッグ開始前の場所・デスクトップ位置にそのまま残ります。
- **マルチディスプレイ境界の自動除外**
  - モニターを並べて使っている場合、隣り合うディスプレイ同士が接している境界の辺は自動的に除外します（画面間でファイルを移動する際の誤反応を防止／メニューから切替可能）。
- **誤爆対策と柔軟なカスタマイズ**
  - **修飾キーでの制御**：`常に有効` / `Option (⌥) 押下中は一時無効` / `Option (⌥) 押下中のみ有効` を切り替えできます。
  - **アプリごとの除外**：最前面のアプリ（Figma / Photoshop / ゲームなど）をメニューバーからワンクリックで除外リストに追加・解除できます。
  - **反応する辺・フチ幅の調整**：左・上・右それぞれの個別 ON/OFF、四隅のホットコーナー回避、当たり判定幅（狭い `8pt` / 標準 `14pt` / 広い `24pt`）を選択可能です。
  - **触覚フィードバック**：トラックパッド向けにフチへ触れた瞬間の軽いクリック感（ON/OFF 可能）に対応しています。
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
│   └── QuickDropApp.swift              # 最小の @main エントリポイント
└── QuickDropCore/
    ├── AppDelegate.swift               # 全体制御・ディスプレイ変更監視
    ├── Models/
    │   ├── ScreenEdge.swift            # 3辺座標計算・隣接ディスプレイ境界判定
    │   └── DraggedPayload.swift        # ペーストボード抽出（ファイル / 画像 / Web URL）
    ├── Services/
    │   ├── GlobalDragMonitor.swift     # NSEvent + NSPasteboard(.drag) + 修飾キー/除外アプリ判定
    │   ├── FilePreviewProvider.swift   # QuickLook サムネイル事前取得＋アイコン即時フォールバック
    │   ├── AirDropService.swift        # NSSharingService(.sendViaAirDrop) + 一時PNG後始末
    │   └── QuickDropSettings.swift     # UserDefaults / SMAppService 設定管理
    └── UI/
        ├── EdgeGlowView.swift          # 3辺のアンビエント発光＋画面外へのふわっとアニメーション
        ├── EdgeDropPanel.swift         # 画面端の透明ドロップ受け皿（.move 非許可）
        ├── EdgeOverlayCoordinator.swift# 全ディスプレイ統合・触覚フィードバック制御
        └── MenuBarController.swift     # メニューバー UI
```

---

## ライセンス

[MIT License](LICENSE)
