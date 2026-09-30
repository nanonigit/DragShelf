# 修正記録：ログイン時起動

1. 同梱ヘルパーの本体バンドルIDを修正し、失敗時のログを追加しました。
2. DragShelf 専用のユーザー用 LaunchAgent plist だけを作成・削除する `LoginLaunchAgent` を追加しました。ログイン時は `/usr/bin/open -a /Applications/DragShelf.app --args --login-start` を実行します。
3. インストール済みアプリの起動時、旧 `SMAppService` の項目が有効なら新方式へ移行し、失敗していた旧サービスを解除します。オフの利用者を勝手にオンにはしません。管理画面は新設定と移行エラーを表示します。
4. 本体とヘルパーの `CFBundleVersion` を `5` に上げ、値が一致しない配布物は作成しないようにしました。
5. Agent の作成、パス更新、削除の単体テストを追加しました。全19テストが通りました。
6. `/Applications/DragShelf.app` にインストールしました。`launchctl bootstrap gui/503` でアプリは `--login-start` 付きで起動し、新ジョブの終了コードは `0`、旧サービスは存在しない状態でした。

制限：現在のユーザーセッションで起動経路を再現しましたが、実際のログアウト／ログインはまだ実施していません。
