import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

enum L {
    static var current: Language {
        get {
            if let raw = UserDefaults.standard.string(forKey: "ClamKeepLanguage"),
               let lang = Language(rawValue: raw) {
                return lang
            }
            return .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ClamKeepLanguage")
        }
    }

    // MARK: - Status
    static var statusActive: String {
        switch current {
        case .english: return "Sleep: disabled"
        case .russian: return "Режим сна: отключён"
        }
    }
    static var statusInactive: String {
        switch current {
        case .english: return "Sleep: standard"
        case .russian: return "Режим сна: стандартный"
        }
    }
    static var wakeTime: String {
        switch current {
        case .english: return "Active time"
        case .russian: return "Время работы"
        }
    }

    // MARK: - Actions
    static var enableWake: String {
        switch current {
        case .english: return "Enable Wake Mode"
        case .russian: return "Включить бодрствование"
        }
    }
    static var disableWake: String {
        switch current {
        case .english: return "Disable Wake Mode"
        case .russian: return "Выключить бодрствование"
        }
    }

    // MARK: - Settings
    static var settings: String {
        switch current {
        case .english: return "Settings"
        case .russian: return "Настройки"
        }
    }
    static var launchAtLogin: String {
        switch current {
        case .english: return "Launch at Login"
        case .russian: return "Запускать при входе в систему"
        }
    }
    static var language: String {
        switch current {
        case .english: return "Language"
        case .russian: return "Язык"
        }
    }

    // MARK: - About & Quit
    static var about: String {
        switch current {
        case .english: return "About ClamKeep"
        case .russian: return "О приложении"
        }
    }
    static var quit: String {
        switch current {
        case .english: return "Quit"
        case .russian: return "Выход"
        }
    }

    // MARK: - About dialog
    static var aboutTitle: String { "ClamKeep" }
    static var aboutVersion: String { "1.0.0" }
    static var aboutDescription: String {
        switch current {
        case .english: return "Version 1.0.0\n\nPrevents your Mac from sleeping when the lid is closed.\n\nAuthor: m3etis@gmail.com"
        case .russian: return "Версия 1.0.0\n\nПредотвращает уход Mac в сон при закрытой крышке.\n\nАвтор: m3etis@gmail.com"
        }
    }

    // MARK: - Quit dialog
    static var quitConfirmTitle: String {
        switch current {
        case .english: return "Wake Mode Active"
        case .russian: return "Бодрствование активно"
        }
    }
    static var quitConfirmMessage: String {
        switch current {
        case .english: return "Wake mode will be disabled before quitting. Continue?"
        case .russian: return "Режим бодрствования будет отключён перед выходом. Продолжить?"
        }
    }
    static var quitButton: String {
        switch current {
        case .english: return "Quit"
        case .russian: return "Выйти"
        }
    }
    static var cancelButton: String {
        switch current {
        case .english: return "Cancel"
        case .russian: return "Отмена"
        }
    }

    // MARK: - Install dialog
    static var installTitle: String {
        switch current {
        case .english: return "Install Component"
        case .russian: return "Установка компонента"
        }
    }
    static var installMessage: String {
        switch current {
        case .english: return "ClamKeep needs to install a background component to manage sleep without password prompts.\n\nAdministrator password required (one time only)."
        case .russian: return "ClamKeep нужно установить фоновый компонент для управления сном без запроса пароля.\n\nПотребуется пароль администратора (один раз)."
        }
    }
    static var installButton: String {
        switch current {
        case .english: return "Install"
        case .russian: return "Установить"
        }
    }
    static var installErrorTitle: String {
        switch current {
        case .english: return "Installation Error"
        case .russian: return "Ошибка установки"
        }
    }
}
