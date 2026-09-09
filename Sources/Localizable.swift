import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    case kazakh = "kk"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .kazakh:  return "Қазақша"
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
        case .kazakh:  return "Ұйқы: өшірілген"
        }
    }
    static var statusInactive: String {
        switch current {
        case .english: return "Sleep: standard"
        case .russian: return "Режим сна: стандартный"
        case .kazakh:  return "Ұйқы: стандартты"
        }
    }
    static var wakeTime: String {
        switch current {
        case .english: return "Active time"
        case .russian: return "Время работы"
        case .kazakh:  return "Белсенді уақыт"
        }
    }

    // MARK: - Actions
    static var enableWake: String {
        switch current {
        case .english: return "Enable Wake Mode"
        case .russian: return "Включить бодрствование"
        case .kazakh:  return "Ояу режимді қосу"
        }
    }
    static var disableWake: String {
        switch current {
        case .english: return "Disable Wake Mode"
        case .russian: return "Выключить бодрствование"
        case .kazakh:  return "Ояу режимді өшіру"
        }
    }

    // MARK: - Settings
    static var settings: String {
        switch current {
        case .english: return "Settings"
        case .russian: return "Настройки"
        case .kazakh:  return "Баптаулар"
        }
    }
    static var launchAtLogin: String {
        switch current {
        case .english: return "Launch at Login"
        case .russian: return "Запускать при входе в систему"
        case .kazakh:  return "Жүйеге кіргенде іске қосу"
        }
    }
    static var language: String {
        switch current {
        case .english: return "Language"
        case .russian: return "Язык"
        case .kazakh:  return "Тіл"
        }
    }
    static var iconStyle: String {
        switch current {
        case .english: return "Icon"
        case .russian: return "Иконка"
        case .kazakh:  return "Белгіше"
        }
    }

    // MARK: - About & Quit
    static var about: String {
        switch current {
        case .english: return "About ClamKeep"
        case .russian: return "О приложении"
        case .kazakh:  return "Қолданба туралы"
        }
    }
    static var quit: String {
        switch current {
        case .english: return "Quit"
        case .russian: return "Выход"
        case .kazakh:  return "Шығу"
        }
    }

    // MARK: - About dialog
    static var aboutTitle: String { "ClamKeep" }
    static var aboutVersion: String { "1.3.1" }
    static var aboutDescription: String {
        switch current {
        case .english: return "Version 1.3.1\n\nKeeps your Mac awake with lid closed and prevents screen dimming with lid open.\n\nhttps://github.com/M3etis/ClamKeep\n\nAuthor: m3etis@gmail.com"
        case .russian: return "Версия 1.3.1\n\nДержит Mac активным при закрытой крышке и предотвращает затемнение экрана при открытой.\n\nhttps://github.com/M3etis/ClamKeep\n\nАвтор: m3etis@gmail.com"
        case .kazakh:  return "Нұсқа 1.3.1\n\nMac құрылғыңызды қақпағы жабылған кезде ояу ұстайды және қақпағы ашылған кезде экранның өшуіне жол бермейді.\n\nhttps://github.com/M3etis/ClamKeep\n\nАвтор: m3etis@gmail.com"
        }
    }

    // MARK: - Quit dialog
    static var quitConfirmTitle: String {
        switch current {
        case .english: return "Wake Mode Active"
        case .russian: return "Бодрствование активно"
        case .kazakh:  return "Ояу режимі белсенді"
        }
    }
    static var quitConfirmMessage: String {
        switch current {
        case .english: return "Wake mode will be disabled before quitting. Continue?"
        case .russian: return "Режим бодрствования будет отключён перед выходом. Продолжить?"
        case .kazakh:  return "Шығар алдында ояу режимі өшіріледі. Жалғастыру керек пе?"
        }
    }
    static var quitButton: String {
        switch current {
        case .english: return "Quit"
        case .russian: return "Выйти"
        case .kazakh:  return "Шығу"
        }
    }
    static var cancelButton: String {
        switch current {
        case .english: return "Cancel"
        case .russian: return "Отмена"
        case .kazakh:  return "Бас тарту"
        }
    }

    // MARK: - Display Sleep Option
    static var keepScreenOn: String {
        switch current {
        case .english: return "Allow Display Sleep"
        case .russian: return "Разрешить сон дисплея"
        case .kazakh:  return "Дисплей ұйқысына рұқсат ету"
        }
    }
    static var statusActiveDisplaySleep: String {
        switch current {
        case .english: return "Sleep: disabled (display can sleep)"
        case .russian: return "Режим сна: отключён (экран может выкл.)"
        case .kazakh:  return "Ұйқы: өшірілген (экран өше алады)"
        }
    }

    // MARK: - Stay Awake Until
    static var stayAwakeUntil: String {
        switch current {
        case .english: return "Stay Awake Until…"
        case .russian: return "Не засыпать до…"
        case .kazakh:  return "Ояу болып тұру…"
        }
    }
    static var noRunningApps: String {
        switch current {
        case .english: return "No running apps"
        case .russian: return "Нет запущенных приложений"
        case .kazakh:  return "Іске қосылған қолданбалар жоқ"
        }
    }
    static func watchingApp(_ name: String) -> String {
        switch current {
        case .english: return "Watching: \(name)"
        case .russian: return "Слежение: \(name)"
        case .kazakh:  return "Бақылануда: \(name)"
        }
    }

    // MARK: - Setup dialog
    static var setupTitle: String {
        switch current {
        case .english: return "Setup Required"
        case .russian: return "Требуется настройка"
        case .kazakh:  return "Баптау қажет"
        }
    }
    static var setupMessage: String {
        switch current {
        case .english: return "ClamKeep needs to install a background component to control Mac sleep mode.\n\nYou will be asked for your administrator password."
        case .russian: return "ClamKeep нужно установить фоновый компонент для управления режимом сна Mac.\n\nВам будет предложено ввести пароль администратора."
        case .kazakh:  return "ClamKeep Mac ұйқы режимін басқару үшін фондық компонентті орнатуы керек.\n\nСізден әкімші құпия сөзі сұралады."
        }
    }
    static var setupButton: String {
        switch current {
        case .english: return "Continue"
        case .russian: return "Продолжить"
        case .kazakh:  return "Жалғастыру"
        }
    }
    static var setupErrorTitle: String {
        switch current {
        case .english: return "Setup Error"
        case .russian: return "Ошибка настройки"
        case .kazakh:  return "Баптау қатесі"
        }
    }
    static var promptExplanation: String {
        switch current {
        case .english: return "ClamKeep requires administrator privileges to install its helper daemon. This daemon uses pmset to prevent your Mac from sleeping when the lid is closed."
        case .russian: return "ClamKeep требуются права администратора для установки вспомогательного компонента. Этот компонент использует pmset для предотвращения засыпания Mac при закрытой крышке."
        case .kazakh:  return "ClamKeep көмекші қызметті орнату үшін әкімші құқықтары қажет. Бұл қызмет pmset арқылы қақпақ жабылған кезде Mac ұйықтап қалуына жол бермейді."
        }
    }

    // MARK: - Common buttons
    static var okButton: String {
        switch current {
        case .english: return "OK"
        case .russian: return "OK"
        case .kazakh:  return "OK"
        }
    }
    static var githubButton: String {
        switch current {
        case .english: return "GitHub"
        case .russian: return "GitHub"
        case .kazakh:  return "GitHub"
        }
    }
}
