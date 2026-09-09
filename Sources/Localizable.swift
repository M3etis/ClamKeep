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
    static var iconStyle: String {
        switch current {
        case .english: return "Icon"
        case .russian: return "Иконка"
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
    static var aboutVersion: String { "1.3.0" }
    static var aboutDescription: String {
        switch current {
        case .english: return "Version 1.3.0\n\nKeeps your Mac awake with lid closed and prevents screen dimming with lid open.\n\nhttps://github.com/M3etis/ClamKeep\n\nAuthor: m3etis@gmail.com"
        case .russian: return "Версия 1.3.0\n\nДержит Mac активным при закрытой крышке и предотвращает затемнение экрана при открытой.\n\nhttps://github.com/M3etis/ClamKeep\n\nАвтор: m3etis@gmail.com"
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

    // MARK: - Display Sleep Option
    static var keepScreenOn: String {
        switch current {
        case .english: return "Allow Display Sleep"
        case .russian: return "Разрешить сон дисплея"
        }
    }
    static var statusActiveDisplaySleep: String {
        switch current {
        case .english: return "Sleep: disabled (display can sleep)"
        case .russian: return "Режим сна: отключён (экран может выкл.)"
        }
    }

    // MARK: - Stay Awake Until
    static var stayAwakeUntil: String {
        switch current {
        case .english: return "Stay Awake Until…"
        case .russian: return "Не засыпать до…"
        }
    }
    static var noRunningApps: String {
        switch current {
        case .english: return "No running apps"
        case .russian: return "Нет запущенных приложений"
        }
    }
    static func watchingApp(_ name: String) -> String {
        switch current {
        case .english: return "Watching: \(name)"
        case .russian: return "Слежение: \(name)"
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

    // MARK: - Daemon update dialog
    static var daemonUpdateTitle: String {
        switch current {
        case .english: return "Update Component"
        case .russian: return "Обновление компонента"
        }
    }
    static var daemonUpdateMessage: String {
        switch current {
        case .english: return "ClamKeep needs to update its background component.\n\nAdministrator password required."
        case .russian: return "ClamKeep нужно обновить фоновый компонент.\n\nПотребуется пароль администратора."
        }
    }

    // MARK: - Common buttons
    static var okButton: String {
        switch current {
        case .english: return "OK"
        case .russian: return "OK"
        }
    }
    static var githubButton: String {
        switch current {
        case .english: return "GitHub"
        case .russian: return "GitHub"
        }
    }
}
