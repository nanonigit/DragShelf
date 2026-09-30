# ログイン時に起動しない問題 — 2026-09-30

## 症状と環境

「ログイン時に起動」がオンでも、ログイン後に DragShelf が起動しませんでした。対象は `/Applications/DragShelf.app` に置かれた、アドホック署名の v0.1.4 です。

## 再現と証拠

1. 旧 `SMAppService` のログイン項目は登録済み・有効と表示されました。
2. `launchctl print gui/503/com.github.nanonigit.DragShelf.LoginItem` には、数百回の試行、`EX_CONFIG`、`job state = spawn failed` が記録されました。
3. v0.1.5 の項目を登録し直すと、`launchd` はヘルパーのパスを解決したものの、`OS_REASON_CODESIGNING | Launch Constraint Violation` で拒否しました。`amfid` はヘルパーがアドホック署名だと記録しました。
4. 調査中は開発用の `dist/DragShelf.app` も動いていたため、インストール済みアプリの検証前に停止しました。

管理画面を出さない仕様のため「見えない」だけでなく、ログイン項目自体が起動できていませんでした。

## 修正と確認

有効な旧方式の登録を、ユーザー用 LaunchAgent から Apple の `/usr/bin/open` を使って `/Applications/DragShelf.app` を `--login-start` で開く方式へ移行し、旧登録を解除しました。`launchctl bootstrap` は成功し、アプリは `/Applications` から `--login-start` 付きで起動しました。Agent の終了コードは `0` です。実際のログアウト／ログインはまだ確認していません。
