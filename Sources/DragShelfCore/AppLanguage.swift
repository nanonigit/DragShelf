import Foundation

public enum AppLanguage: String, CaseIterable {
    case english = "en"
    case japanese = "ja"

    public static let preferenceKey = "appLanguage"

    public static func restored(from defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .english
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.preferenceKey)
    }

    public var nativeName: String {
        switch self {
        case .english: "English"
        case .japanese: "日本語"
        }
    }
}

/// An exhaustive catalog keeps both languages together and prevents unknown lookup keys.
public enum AppText: CaseIterable {
    case general
    case shelfAppearance
    case permissionHelpTitle
    case openManagement
    case showShelf
    case hideShelf
    case quit
    case checking
    case inputSettingsError
    case inputSettingsHelp
    case loginErrorStatus
    case loginEnabled
    case legacyLoginApproval
    case disabled
    case stopped
    case monitorWithPermission
    case monitorWithoutPermission
    case dockError
    case restartHelp
    case loginError
    case emptyFiles
    case enable
    case show
    case openInputSettings
    case permissionHelp
    case managementTitle
    case settings
    case parkedItems
    case parkedFiles
    case list
    case icons
    case leftBottom
    case leftTop
    case rightBottom
    case rightTop
    case nearDrag
    case transparencyHelp
    case appearance
    case displayMode
    case placement
    case transparency
    case menuBarIcon
    case dockIcon
    case history
    case maximumItems
    case historyHelp
    case startup
    case launchAtLogin
    case dragDetection
    case inputMonitoring
    case currentStatus
    case emptyCount
    case presenceHelp
    case permissionGranted
    case permissionDenied
    case missingFile
    case remove
    case removeHelp
    case previewHelp
    case dropHere
    case language
    case parkedCount
    case historyCount
    case managementCount

    public func text(in language: AppLanguage) -> String {
        let translations: (english: String, japanese: String)
        switch self {
        case .general: translations = ("General", "基本設定")
        case .shelfAppearance: translations = ("Shelf Appearance", "棚の表示")
        case .permissionHelpTitle: translations = ("Help", "ヘルプ")
        case .openManagement: translations = ("Open Settings", "管理画面を開く")
        case .showShelf: translations = ("Show Shelf", "棚を表示")
        case .hideShelf: translations = ("Hide Shelf", "棚を隠す")
        case .quit: translations = ("Quit", "終了")
        case .checking: translations = ("Checking", "確認中")
        case .inputSettingsError: translations = ("Could Not Open Input Monitoring Settings", "入力監視の設定を開けませんでした")
        case .inputSettingsHelp: translations = ("Allow DragShelf in System Settings → Privacy & Security → Input Monitoring.", "システム設定 → プライバシーとセキュリティ → 入力監視 から DragShelf を許可してください。")
        case .loginErrorStatus: translations = ("Setup failed (toggle again to retry)", "設定エラー（もう一度切り替えてください）")
        case .loginEnabled: translations = ("Enabled (starts at next login)", "有効（次回ログイン時に起動）")
        case .legacyLoginApproval: translations = ("Previous login item awaiting approval", "旧項目の承認待ち")
        case .disabled: translations = ("Disabled", "無効")
        case .stopped: translations = ("Stopped", "停止中")
        case .monitorWithPermission: translations = ("Running (using Input Monitoring)", "動作中（入力監視を使用）")
        case .monitorWithoutPermission: translations = ("Running (without Input Monitoring)", "動作中（入力監視なし）")
        case .dockError: translations = ("Could Not Change Dock Icon Visibility", "Dock アイコンの表示を変更できませんでした")
        case .restartHelp: translations = ("Restart the app and try again.", "アプリを再起動してから、もう一度お試しください。")
        case .loginError: translations = ("Could Not Change Launch at Login", "ログイン時起動を変更できませんでした")
        case .emptyFiles: translations = ("Files dropped on the shelf appear here.", "ファイルを棚へドラッグすると、ここに表示されます")
        case .enable: translations = ("Enable", "有効にする")
        case .show: translations = ("Show", "表示する")
        case .openInputSettings: translations = ("Open Input Monitoring Settings", "入力監視の設定を開く")
        case .permissionHelp: translations = ("If permission is enabled in System Settings but not recognized here, an update may have changed the app signature. Toggle permission off and on, then restart DragShelf.", "設定が ON でも未許可なら、アプリ更新で署名が変わった可能性があります。設定を OFF→ON にし、アプリを再起動してください。")
        case .managementTitle: translations = ("DragShelf Settings", "DragShelf の管理")
        case .settings: translations = ("Settings", "設定")
        case .parkedItems: translations = ("Parked Items", "一時置き")
        case .parkedFiles: translations = ("Parked Files", "一時置きしたファイル")
        case .list: translations = ("List", "リスト")
        case .icons: translations = ("Icons", "アイコン")
        case .leftBottom: translations = ("Bottom Left", "左下")
        case .leftTop: translations = ("Top Left", "左上")
        case .rightBottom: translations = ("Bottom Right", "右下")
        case .rightTop: translations = ("Top Right", "右上")
        case .nearDrag: translations = ("Near Pointer", "ファイルの近く")
        case .transparencyHelp: translations = ("0% (opaque) to 60% (transparent)", "0%（不透明）〜60%（透明）")
        case .appearance: translations = ("Appearance", "表示")
        case .displayMode: translations = ("Display Mode", "表示形式")
        case .placement: translations = ("Shelf Position", "棚の位置")
        case .transparency: translations = ("Transparency", "棚の透明度")
        case .menuBarIcon: translations = ("Menu Bar Icon", "メニューバーアイコン")
        case .dockIcon: translations = ("Dock Icon", "Dock アイコン")
        case .history: translations = ("History", "履歴")
        case .maximumItems: translations = ("History Limit", "最大保存件数")
        case .historyHelp: translations = ("Older items are removed from the shelf when the limit is reached. Original files are not deleted.", "上限を超えると古い項目から棚を外します。元のファイルは消しません。")
        case .startup: translations = ("Startup", "起動")
        case .launchAtLogin: translations = ("Launch at Login", "ログイン時に起動")
        case .dragDetection: translations = ("Drag Detection", "ドラッグ検知")
        case .inputMonitoring: translations = ("Input Monitoring", "入力監視")
        case .currentStatus: translations = ("Current Status", "現在の動作")
        case .emptyCount: translations = ("The shelf is empty. Drag files onto it to park them.", "棚は空です。ファイルをドラッグして一時置きできます。")
        case .presenceHelp: translations = ("Even with both icons hidden, open DragShelf from Applications to return to Settings.", "両方を隠した場合も「アプリケーション」から DragShelf を開くと管理画面に戻れます。")
        case .permissionGranted: translations = ("Permission recognized by DragShelf", "アプリ側で許可済み")
        case .permissionDenied: translations = ("Permission not recognized by DragShelf", "アプリ側では未許可")
        case .missingFile: translations = ("Original file not found", "元ファイルが見つかりません")
        case .remove: translations = ("Remove from Shelf", "棚から取り外す")
        case .removeHelp: translations = ("Remove from shelf (original file is not deleted)", "棚から取り外す（元のファイルは消しません）")
        case .previewHelp: translations = ("Click a file, then press Space to preview", "ファイルをクリックし、スペースキーでプレビュー")
        case .dropHere: translations = ("Drop Files Here", "ここにドロップ")
        case .language: translations = ("Language / 言語", "言語")
        case .parkedCount: translations = ("Parked: %d items", "一時置き: %d 件")
        case .historyCount: translations = ("%d items", "%d 件")
        case .managementCount: translations = ("Parked: %d / %d items. Use × to remove from the shelf.", "一時置き: %d / %d 件　　× で棚から取り外せます。")
        }
        return language == .english ? translations.english : translations.japanese
    }
}
