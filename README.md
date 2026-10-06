# DragShelf

**A place to put files down before you drag them somewhere else.**

**ファイルをいったん置いて、移動先を開いてから、もう一度ドラッグ。**

[English](#english) · [日本語](#日本語)

## English

### Stop holding the mouse button while you find the destination

Dragging a file is easy when its destination is already visible. It becomes awkward when you need to switch apps, find a buried window, or navigate to another folder while keeping the mouse button pressed.

DragShelf gives you a small shelf on your Mac so you can pause a drag and continue it later:

1. **Put it down.** Start dragging a file or folder from Finder. When the shelf appears, drop it onto the shelf and release the mouse button.
2. **Find the destination.** Switch windows or apps and open the folder or document you need, with your mouse free.
3. **Pick it up again.** Drag the file from the shelf to the destination.

The shelf is an intermediate stop, not a new folder. Parking a file stores a reference to it; it does not move, duplicate, or delete the original.

### When it helps

- **The destination is behind another window.** Park the file, bring the destination forward, then drag it out of the shelf.
- **You need to prepare an attachment or upload.** Put the file on the shelf before opening the message or upload form, then drag it into an accepting app.
- **Files are in different folders.** Park them as you find them so they are together on the shelf when you are ready to use them.

DragShelf is designed to help with switching between windows, apps, and Spaces. It is still experimental: drag detection and destination compatibility vary, and full-screen and multi-display workflows need broader hands-on testing.

### More than a drop target

- **Recognize what you parked.** List and icon views show filenames and thumbnails where macOS can generate them, with file icons as a fallback.
- **Check a file before using it.** Click its thumbnail or name, keep the pointer over it, and press **Space** for native Quick Look. Press Space again or **Esc** to close.
- **Pick up where you left off.** File references survive an app restart. Choose a maximum of 5, 10, 25, 50, or 100 entries (default: 25); exceeding it removes the oldest references from the shelf, not the disk.
- **Clear the shelf safely.** Each × removes an entry from DragShelf only. Removing the last entry hides the shelf.

DragShelf is not a backup, cloud drive, or clipboard recorder. It currently accepts local files and folders, not arbitrary text, URLs, images copied from apps, or promised downloads. The original file must remain available for its reference to be useful. Missing files remain listed as unavailable; bookmarks can usually follow moved files, but recovery is not guaranteed.

### Make the shelf fit your workspace

Open management from the shelf's gear, the menu-bar menu, or by opening DragShelf from Applications. **Settings** contains the shelf's appearance, history limit, and startup options; **Parked Items** lets you review and remove entries.

You can choose any of the four screen corners or a position near the dragged file, switch between list and icon views, and adjust transparency from 0–60%. The shelf stays in front while it holds files. You can also enable launch at login and choose whether to show the menu-bar and Dock icons. Even with both icons hidden, opening DragShelf from Applications brings back management. The menu-bar menu provides manual Show/Hide Shelf actions.

### Install

Requirements: **macOS 14 or later**. The current v0.1.6 download is for **Apple Silicon (arm64)** Macs.

**Signing notice:** the app is ad-hoc signed, not Developer ID signed or notarized. Gatekeeper may block a downloaded copy. Review the source and release before deciding whether to allow it in **System Settings → Privacy & Security**. The Homebrew tap does not bypass Gatekeeper.

With the [dedicated Homebrew tap](https://github.com/nanonigit/homebrew-DragShelf):

```bash
brew tap nanonigit/dragshelf
brew install --cask dragshelf
```

Or download `DragShelf-0.1.6-macos-arm64.zip` from [GitHub Releases](https://github.com/nanonigit/DragShelf/releases), extract it, and put `DragShelf.app` in **Applications**.

### Permissions and current limitations

DragShelf requests **Input Monitoring** at launch when it is not granted, to support drag detection. You control this permission in macOS; management shows the app's actual access check and active detection mode. An AppKit fallback may work without Input Monitoring. Manual shelf use remains available, and Quick Look needs no additional keyboard-monitoring permission.

Ad-hoc-signed updates can invalidate Input Monitoring access even when its switch still looks on. If management reports it as unavailable after an update, re-grant permission for the installed app in System Settings and restart DragShelf.

Launch at login starts the installed app quietly, without opening management. Its startup job has been tested in a running session, but a real logout/login still needs user confirmation. Before uninstalling, turn this option off in DragShelf.

For measured results and open checks—including cross-app drops, full-screen Spaces, multiple displays, and keyboard-focus return—see [verification.md](verification.md).

### Build from source

Requires Xcode/Swift with Swift Package Manager.

```bash
git clone https://github.com/nanonigit/DragShelf.git
cd DragShelf
swift test
bash script/build_and_run.sh --build-only
```

Copy the resulting `dist/DragShelf.app` to **Applications** and open it there. The build-only command does not restart an existing instance. Development and release procedures are in [design.md](design.md) and [verification.md](verification.md).

## 日本語

### 移動先を探す間、マウスを押し続けなくていい

ファイルの移動先が見えていれば、ドラッグ＆ドロップは簡単です。でも、別のアプリへ切り替えたり、奥に隠れたウィンドウを開いたり、別のフォルダへ移動したりする間も、マウスのボタンを押し続けるのは面倒です。

DragShelf は、ドラッグを途中で区切り、あとから続けられるようにする、Mac の小さな「一時置きの棚」です。

1. **いったん置く。** Finder からファイルやフォルダをドラッグし、現れた棚にドロップします。ここでマウスのボタンを離せます。
2. **移動先を開く。** 手を自由にしてウィンドウやアプリを切り替え、目的のフォルダや書類を開きます。
3. **棚から取り出す。** 棚のファイルを、開いた移動先へドラッグします。

棚は、新しい保存先のフォルダではなく、ドラッグの途中で立ち寄る場所です。保存するのはファイルへの参照だけで、棚に置くときに元ファイルを移動・複製・削除することはありません。

### こんなときに便利です

- **移動先が別のウィンドウの裏にある。** 棚に置いてから移動先を手前に出し、棚からドラッグできます。
- **添付やアップロードの画面をまだ開いていない。** 先にファイルを棚へ置き、メッセージやアップロード画面を準備してから、ファイルを受け取れるアプリへ渡せます。
- **使いたいファイルが別々のフォルダにある。** 見つけたものから棚に集め、使うときに取り出せます。

ウィンドウ・アプリ・Spaces を切り替える場面での利用を想定しています。ただし、現時点では実験的なアプリです。ドラッグ検知や受け渡し先との相性には差があり、フルスクリーンや複数ディスプレイでの動作は追加の実機検証が必要です。

### 置いたあとも、探しやすく・使いやすく

- **何を置いたか見える。** リスト／アイコン表示でファイル名を確認でき、macOS が生成できる場合はサムネイルも表示します。生成できない場合はファイルのアイコンを使います。
- **使う前に中身を確認できる。** サムネイルや名前をクリックし、カーソルをその上に置いて **スペースキー** を押すと、標準のクイックルックでプレビューできます。もう一度スペースキー、または **Esc** で閉じます。
- **再起動後も続きを使える。** ファイルへの参照はアプリを終了しても残ります。保存件数は 5／10／25／50／100 件から選択でき、初期値は 25 件です。上限を超えると、古い参照から棚を外します。ディスク上のファイルは消しません。
- **棚だけを片付けられる。** 各項目の × は棚から取り外すためのボタンです。元ファイルは削除しません。最後の項目を取り外すと棚が隠れます。

DragShelf は、バックアップ・クラウドストレージ・クリップボードの自動記録アプリではありません。現在対応するのはローカルのファイルとフォルダです。アプリから取り出した任意のテキストや URL、コピーした画像、未完了のダウンロードなどには対応していません。参照先の元ファイルは引き続き必要です。見つからないファイルは利用不可として残り、移動したファイルは通常ブックマークで追跡できますが、必ず復元できるとは限りません。

### 自分の作業環境に合わせる

棚の歯車、メニューバーのメニュー、または「アプリケーション」から DragShelf を開くと、管理画面を表示できます。「設定」には棚の見た目・履歴件数・起動の設定を、「一時置き」には置いたファイルの確認と取り外しをまとめています。

棚の位置は画面の四隅、またはドラッグ中のファイルの近くから選べます。リスト／アイコン表示と透明度（0〜60%）も変更できます。ファイルが入っている間、棚は手前に表示されます。ログイン時の自動起動、メニューバーと Dock のアイコン表示も選べます。両方のアイコンを隠しても、「アプリケーション」から DragShelf を開けば管理画面に戻れます。メニューバーからは棚を手動で表示・非表示にできます。

### インストール

動作環境は **macOS 14 以降**です。現在の v0.1.6 の配布バイナリは **Apple Silicon（arm64）Mac 用**です。

**署名について:** 配布版はアドホック署名のみで、Developer ID 署名・公証はありません。ダウンロードしたアプリは Gatekeeper に止められる場合があります。ソースと配布物を確認し、許可する場合は「システム設定 → プライバシーとセキュリティ」から操作してください。Homebrew tap は Gatekeeper を自動で回避しません。

[専用 Homebrew tap](https://github.com/nanonigit/homebrew-DragShelf) を使う場合:

```bash
brew tap nanonigit/dragshelf
brew install --cask dragshelf
```

または、[GitHub Releases](https://github.com/nanonigit/DragShelf/releases) から `DragShelf-0.1.6-macos-arm64.zip` を取得し、展開した `DragShelf.app` を **「アプリケーション」**へ置きます。

### 権限と、現在の制限

ドラッグ検知のため、未許可の場合は起動時に **入力監視**の許可を求めます。許可は利用者自身が macOS で操作するもので、管理画面にはアプリ側の実際の判定と検知方式を表示します。入力監視なしでも AppKit による代替方式が動く場合があります。棚の手動操作は引き続き利用でき、クイックルックのための追加のキーボード監視権限は不要です。

アドホック署名版では、更新後に入力監視のスイッチが ON のままでも許可が失われる場合があります。管理画面で未許可になっているときは、システム設定でインストール済みアプリへの許可を設定し直し、DragShelf を再起動してください。

ログイン時起動では、インストール済みアプリを管理画面なしで起動します。起動ジョブは動作中のセッションで検証していますが、実際のログアウト／ログイン後の確認はまだ必要です。アンインストール前には、DragShelf のこの設定をオフにしてください。

アプリ間の受け渡し、フルスクリーン、複数ディスプレイ、棚から離れた際のキーフォーカスなど、検証済みの範囲と未確認の項目は [verification.md](verification.md) に記録しています。

### ソースからビルド

Swift Package Manager を使える Xcode／Swift が必要です。

```bash
git clone https://github.com/nanonigit/DragShelf.git
cd DragShelf
swift test
bash script/build_and_run.sh --build-only
```

生成された `dist/DragShelf.app` を **「アプリケーション」**へコピーし、そこから開きます。`--build-only` は動作中のアプリを再起動しません。開発・配布の手順は [design.md](design.md) と [verification.md](verification.md) を参照してください。

---

Development notes / 開発記録: [Requirements / 要件](requirements.md) · [Design / 設計](design.md) · [Tasks / 作業項目](tasks.md) · [Verification / 検証記録](verification.md)

License / ライセンス: [MIT](LICENSE).
