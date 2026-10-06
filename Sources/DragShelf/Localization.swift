import Foundation
import DragShelfCore

func L(_ key: AppText, _ arguments: CVarArg...) -> String {
    let language = AppLanguage.restored(from: .standard)
    let template = key.text(in: language)
    return arguments.isEmpty ? template : String(format: template, arguments: arguments)
}
