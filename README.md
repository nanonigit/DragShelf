# DragShelf

DragShelf is an experimental macOS shelf for temporarily parking files during drag and drop. It reveals a narrow drop target while you drag a file from Finder, and lets you drag parked files onward later. It does **not** move, delete, or copy the source file when parking it.

DragShelf は、ドラッグ中のファイルを一時的に置くための macOS アプリです。Finder などからファイルをドラッグすると細い棚を表示し、置いたファイルを後で別の場所へドラッグできます。一時置き時に元ファイルを移動・削除・複製しません。

## English

### Requirements and installation

- macOS 14 or later. The v0.1.0 binary is for Apple Silicon (arm64) Macs only. The source build requires Xcode/Swift with Swift Package Manager.
- Download `DragShelf-0.1.0-macos-arm64.zip` from [GitHub Releases](https://github.com/nanonigit/DragShelf/releases), extract it, and move `DragShelf.app` to Applications.
- Alternatively, use the dedicated tap: `brew tap nanonigit/tap && brew install --cask dragshelf` (available after the first release is published).

**Distribution warning:** v0.1.0 is ad-hoc signed, not Developer ID signed or notarized. macOS Gatekeeper may block the downloaded app. Review the source and release before allowing it in **System Settings → Privacy & Security**. The Homebrew tap does not bypass Gatekeeper. If you prefer not to make a security exception, build from source or wait for a notarized release.
With ad-hoc signatures, an updated build may lose macOS Input Monitoring access even if its switch still looks enabled. The management window reports the app's actual access check and active detection mode; the AppKit fallback remains available.

### Use

Drag a file or folder from Finder. When the shelf appears, drop it there. Drag a parked item out to Finder or another app. The menu-bar icon offers management and Show/Hide Shelf. The gear on the shelf also opens management. Management has **Parked Items** and **Settings** tabs; Settings contains list/icon display, placement, shelf transparency (0–60%), menu-bar icon visibility, launch at login, Input Monitoring, and the history limit (5/10/25/50/100 items, default 25). If you hide the menu-bar icon, open DragShelf again from Applications or the Dock to reach Settings and show it again. Removing the last item hides the shelf.

On launch, DragShelf requests Input Monitoring once if it is missing. The button in management opens the relevant System Settings pane. macOS permission must be granted by you; DragShelf cannot grant it. Drag detection also has an AppKit fallback that may work without this permission. Management reports which mode is running.

Parked file references are stored locally and restored after a restart; file contents are not copied. If the item count exceeds your chosen limit, oldest references are removed from the shelf, never from the disk. Moved files are usually tracked by macOS bookmarks; missing files remain listed as unavailable until you remove them or restore the originals. Only local file and folder URLs are currently supported. Cross-app reveal, full-screen Spaces, multi-display placement, and outgoing drops still need broader hands-on validation; see [verification.md](verification.md).

### Build from source

```bash
swift test
bash script/build_and_run.sh
```

`bash script/build_and_run.sh --build-only` builds and stages `dist/DragShelf.app` without restarting a running shelf. `bash script/package_release.sh 0.1.0` creates a release zip and SHA-256 checksum in `releases/`. A normal launch opens the management window; login launch stays in the background.

## 日本語

### 動作環境とインストール

- macOS 14 以降。v0.1.0 の配布バイナリは Apple Silicon（arm64）Mac 専用です。ソースからのビルドには Swift Package Manager を使える Xcode/Swift が必要です。
- [GitHub Releases](https://github.com/nanonigit/DragShelf/releases) から `DragShelf-0.1.0-macos-arm64.zip` を取得し、展開した `DragShelf.app` を「アプリケーション」へ移します。
- 専用 tap からは `brew tap nanonigit/tap && brew install --cask dragshelf` でインストールできます（初回リリース公開後）。

**配布上の注意:** v0.1.0 はアドホック署名のみで、Developer ID 署名・公証はありません。ダウンロードしたアプリは Gatekeeper に止められる場合があります。ソースと配布物を確認したうえで「システム設定 → プライバシーとセキュリティ」から許可してください。Homebrew tap は Gatekeeper を自動で回避しません。セキュリティの例外設定を避けたい場合は、ソースからビルドするか、公証済み版をお待ちください。
アドホック署名版では、更新後に入力監視のスイッチが ON に見えてもアプリ側の許可が失われる場合があります。管理画面にはアプリ側の実際の判定とドラッグ検知方式を表示します。入力監視なしの AppKit 方式も利用できます。

### 使い方

Finder からファイルやフォルダをドラッグし、現れた棚にドロップします。棚から Finder や別のアプリへ再びドラッグできます。メニューバーには管理画面と棚の表示・非表示を残しました。棚の歯車からも管理画面を開けます。管理画面は「一時置き」と「設定」に分かれ、設定にはリスト／アイコン表示、表示位置、透明度（0〜60%）、メニューバーアイコンの表示・非表示、ログイン時起動、入力監視、履歴の上限（5／10／25／50／100 件、初期値 25 件）をまとめています。メニューバーアイコンを隠した後も、「アプリケーション」や Dock から DragShelf を開けば設定に戻して再表示できます。最後の項目を削除すると棚が隠れます。

起動時、入力監視の許可がなければ macOS に一度だけ要求します。管理画面のボタンからシステム設定の該当画面を開けます。許可は利用者自身が行う必要があります。入力監視なしでも AppKit によるドラッグ検知が動く場合があり、現在の動作方式は管理画面に表示されます。

棚に置いたファイルへの参照はこの Mac に保存され、アプリ終了・再起動後も復元されます。ファイル本体はコピーしません。設定した上限を超えると古い参照から棚を外しますが、元ファイルは削除しません。移動したファイルは通常 macOS のブックマークで追跡でき、見つからないファイルは利用不可として表示します。現時点ではローカルのファイル／フォルダ URL のみ対応します。アプリ間の自動表示、フルスクリーン、複数ディスプレイ、棚からのドラッグ先は追加の実機検証が必要です。詳細は [verification.md](verification.md) を参照してください。

### ソースからビルド

```bash
swift test
bash script/build_and_run.sh
```

`bash script/build_and_run.sh --build-only` は動作中の棚を再起動せず `dist/DragShelf.app` を作ります。`bash script/package_release.sh 0.1.0` は `releases/` に ZIP と SHA-256 を作ります。通常起動では管理画面が開き、ログイン時起動では背後で動きます。

Design and development notes / 設計・開発記録: [requirements.md](requirements.md), [design.md](design.md), [tasks.md](tasks.md), [verification.md](verification.md).

License / ライセンス: [MIT](LICENSE).
