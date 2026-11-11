# QuickDrop

ファイルをドラッグしたときだけ画面の **上・左・右の3辺**（下辺を除く）がほのかに光り、そのままフチに触れてドロップするだけで macOS 純正の **AirDrop** 共有画面を呼び出せる、軽量な常駐型オープンソース Mac アプリです。

---

## 特長

- **下辺を除いた3辺だけ光るデザイン**
  - Dock がある下辺は光らず・反応しないため、普段の操作を邪魔しません。
  - ファイルをドラッグしている間だけ3辺がさりげなく発光し、フチに触れるとその辺が明るく反応して `AirDrop で送信` バッジが表示されます。
  - フチにドロップした瞬間、ファイルのサムネイル／アイコンが画面の外へ向かって「ふわっ」と吸い込まれていくアニメーション（視覚演出のみ）とともに AirDrop 画面が開きます。
- **元のファイルは一切動かさない（最初の位置のまま）**
  - ドロップ時は常に非破壊の `.copy`（または `.generic`）としてURL参照のみを受け取り、`.move` を返しません。
  - ファイルを移動したり複製したりせず元のパスをそのまま AirDrop に渡すため、共有完了後（およびキャンセル時）もファイルはドラッグ開始前の場所・位置にそのまま残ります。
- **メニューバー常駐・マルチディスプレイ対応**
  - Dock アイコンを出さない軽量なメニューバーアプリ（`LSUIElement`）です。
  - 複数のディスプレイ環境にも対応し、ドラッグした先のディスプレイの3辺が反応します。
- **ちょっとしたカスタマイズ**
  - 光の色（AirDrop ブルー / ミントグリーン / ピュアホワイト）
  - 光の強さ（ひかえめ / 標準 / くっきり）
  - 四隅の回避設定（macOS ホットコーナー誤爆防止）
  - ログイン時に起動（`.app` バンドル実行時）

---

## 動作環境

- macOS 13 (Ventura) 以降
- Xcode 15+ または Swift 5.9+（ソースからビルドする場合）

---

## ビルドと実行（macOS）

### 1. `.app` バンドルをビルドして起動する（おすすめ）

```bash
git clone https://github.com/<your-username>/QuickDrop.git
cd QuickDrop
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open build/QuickDrop.app
```

`/Applications` にドラッグ＆ドロップして入れれば、メニューバーから「ログイン時に起動」も有効化できます。

### 2. SwiftPM から直接起動する / Xcode で開く

```bash
# ターミナルから直接実行
swift run

# Xcode で開く場合
open Package.swift
```

> **Note:** `swift run` で直接実行する場合は `.app` バンドルではないため、「ログイン時に起動」項目は無効表示になります。

---

## 仕組み（アーキテクチャ）

```text
Sources/QuickDrop/
├── QuickDropApp.swift              # エントリポイント
├── AppDelegate.swift               # 全体制御・ディスプレイ変更監視
├── Models/
│   └── ScreenEdge.swift            # 上・左・右の3辺の座標計算
├── Services/
│   ├── GlobalDragMonitor.swift     # NSEvent + NSPasteboard(.drag) によるファイルドラッグ検知
│   ├── FilePreviewProvider.swift   # QuickLook サムネイル事前取得＋アイコン即時フォールバック
│   ├── AirDropService.swift        # NSSharingService(.sendViaAirDrop) 呼び出し
│   └── QuickDropSettings.swift     # UserDefaults / SMAppService 設定管理
└── UI/
    ├── EdgeGlowView.swift          # 3辺のアンビエント発光（下辺はマスクでフェード）
    ├── EdgeDropPanel.swift         # 画面端の透明ドロップ受け皿（.move 非許可）
    ├── EdgeOverlayCoordinator.swift# 全ディスプレイのオーバーレイ統合管理
    └── MenuBarController.swift     # メニューバー UI
```

1. **ドラッグ検知 (`GlobalDragMonitor`)**
   - `NSEvent.addGlobalMonitorForEvents` と `NSPasteboard(name: .drag).changeCount` を組み合わせ、**新しくファイルがドラッグされた瞬間だけ**反応します（ウィンドウ移動やテキスト選択では反応しません）。
2. **3辺グロー＆ドロップ判定 (`EdgeGlowView` / `EdgeDropPanel`)**
   - 視覚的な光はクリック透過のフルスクリーンオーバーレイで描画し、実際のドロップ判定は3辺外周の極細パネルが受け持ちます。
3. **非破壊ドロップと AirDrop 起動 (`AirDropService`)**
   - `NSDraggingDestination` で `.copy` を返してファイル URL のみを受け取り、`NSSharingService(named: .sendViaAirDrop)` に渡します。

---

## ライセンス

[MIT License](LICENSE)
