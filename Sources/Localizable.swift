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
    static var wakeTimeRemaining: String {
        switch current {
        case .english: return "Time left"
        case .russian: return "Осталось"
        case .kazakh:  return "Қалды"
        }
    }

    // MARK: - Active mode hints (menu header)
    static var activeModesPrefix: String {
        switch current {
        case .english: return "Active:"
        case .russian: return "Активно:"
        case .kazakh:  return "Белсенді:"
        }
    }
    static var modeWake: String {
        switch current {
        case .english: return "wake mode"
        case .russian: return "бодрствование"
        case .kazakh:  return "ояу режим"
        }
    }
    static var modeDisplay: String {
        switch current {
        case .english: return "display on"
        case .russian: return "экран включён"
        case .kazakh:  return "экран қосулы"
        }
    }
    static var modeDisplayMaySleep: String {
        switch current {
        case .english: return "display may sleep"
        case .russian: return "экран может спать"
        case .kazakh:  return "экран өше алады"
        }
    }
    static var modeNoAutoLock: String {
        switch current {
        case .english: return "no auto lock"
        case .russian: return "без автоблокировки"
        case .kazakh:  return "автоблоктаусыз"
        }
    }
    static var modeAutoLockAllowed: String {
        switch current {
        case .english: return "auto lock allowed"
        case .russian: return "автоблокировка разрешена"
        case .kazakh:  return "автоблоктау рұқсат"
        }
    }
    static var modeDownloads: String {
        switch current {
        case .english: return "downloads"
        case .russian: return "загрузки"
        case .kazakh:  return "жүктеулер"
        }
    }
    static func modeApp(_ name: String) -> String {
        switch current {
        case .english: return "app: \(name)"
        case .russian: return "приложение: \(name)"
        case .kazakh:  return "қолданба: \(name)"
        }
    }

    // MARK: - Actions
    static var wakeMode: String {
        switch current {
        case .english: return "Wake Mode"
        case .russian: return "Бодрствование"
        case .kazakh:  return "Ояу режим"
        }
    }

    // MARK: - Auto-off timer
    static var timerMenu: String {
        switch current {
        case .english: return "Auto-off Timer"
        case .russian: return "Таймер"
        case .kazakh:  return "Таймер"
        }
    }
    static var timerOff: String {
        switch current {
        case .english: return "Off"
        case .russian: return "Выкл."
        case .kazakh:  return "Өш."
        }
    }
    static var timerCustom: String {
        switch current {
        case .english: return "Custom…"
        case .russian: return "Своё время…"
        case .kazakh:  return "Басқа уақыт…"
        }
    }
    static var timerCustomTitle: String {
        switch current {
        case .english: return "Custom Timer"
        case .russian: return "Своё время"
        case .kazakh:  return "Басқа уақыт"
        }
    }
    static var timerCustomMessage: String {
        switch current {
        case .english: return "Wake Mode will turn off after this time."
        case .russian: return "Через это время бодрствование выключится."
        case .kazakh:  return "Осы уақыттан кейін ояу режим өшеді."
        }
    }
    static var timerHoursLabel: String {
        switch current {
        case .english: return "Hours"
        case .russian: return "Часы"
        case .kazakh:  return "Сағат"
        }
    }
    static var timerMinutesLabel: String {
        switch current {
        case .english: return "Minutes"
        case .russian: return "Минуты"
        case .kazakh:  return "Минут"
        }
    }
    static func timerMinutes(_ minutes: Int) -> String {
        switch current {
        case .english: return "\(minutes) min"
        case .russian: return "\(minutes) мин"
        case .kazakh:  return "\(minutes) мин"
        }
    }
    static func timerDuration(_ hours: Int, _ minutes: Int) -> String {
        switch current {
        case .english:
            if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
            return "\(minutes) min"
        case .russian:
            if hours > 0 { return String(format: "%dч %02dм", hours, minutes) }
            return "\(minutes) мин"
        case .kazakh:
            if hours > 0 { return String(format: "%dс %02dм", hours, minutes) }
            return "\(minutes) мин"
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
    static var aboutVersion: String { "1.7.0" }
    static var aboutDescription: String {
        switch current {
        case .english: return "Version 1.7.0\n\n• Wake Mode — keeps your Mac awake with the lid closed. The screen stays on and auto-lock waits until you allow them.\n• Allow Display Sleep — lets the screen turn off while Wake Mode is on (off by default).\n• Allow Auto Lock — lets the Mac lock itself after idle while Wake Mode is on (off by default). Manual lock (⌘⌃Q) always locks immediately.\n• Don't Sleep During Downloads — holds wake while downloads are active.\n• Don't Sleep While Active App… — holds wake while a chosen app runs.\n• Auto-off Timer — turns Wake Mode off after the time you pick.\n\nhttps://github.com/M3etis/ClamKeep\n\nAuthor: m3etis@gmail.com"
        case .russian: return "Версия 1.7.0\n\n• Бодрствование — Mac не засыпает при закрытой крышке. Экран остаётся включённым, автоблокировка откладывается, пока вы это не разрешите.\n• Разрешить сон дисплея — экран может гаснуть, пока включено бодрствование (по умолчанию выкл.).\n• Разрешить автоблокировку — Mac может блокироваться по бездействию, пока включено бодрствование (по умолчанию выкл.). Ручная блокировка (⌘⌃Q) срабатывает сразу.\n• Не засыпать пока идет загрузка — не даёт Mac заснуть, пока идут загрузки.\n• Не засыпать пока активное приложение… — не даёт Mac заснуть, пока работает выбранное приложение.\n• Таймер — выключает бодрствование через выбранное время.\n\nhttps://github.com/M3etis/ClamKeep\n\nАвтор: m3etis@gmail.com"
        case .kazakh:  return "Нұсқа 1.7.0\n\n• Ояу режим — қақпақ жабылғанда Mac ұйымайды. Экран қосулы қалады, автоблоктау сіз рұқсат еткенше кейінге қалады.\n• Дисплей ұйқысына рұқсат ету — ояу режимде экран өше алады (әдепкі: өш.).\n• Автоблоктауға рұқсат ету — ояу режимде Mac бос уақытта блокталуы мүмкін (әдепкі: өш.). Қолмен блоктау (⌘⌃Q) бірден жұмыс істейді.\n• Жүктеу кезінде ұйықтамау — жүктеулер жүріп жатқанда ояу ұстайды.\n• Белсенді қолданба кезінде ұйықтамау… — таңдалған қолданба жұмыс істегенде ояу ұстайды.\n• Таймер — таңдалған уақыттан кейін ояу режимді өшіреді.\n\nhttps://github.com/M3etis/ClamKeep\n\nАвтор: m3etis@gmail.com"
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

    // MARK: - Allow Display Sleep Option
    static var allowDisplaySleep: String {
        switch current {
        case .english: return "Allow Display Sleep"
        case .russian: return "Разрешить сон дисплея"
        case .kazakh:  return "Дисплей ұйқысына рұқсат ету"
        }
    }

    // MARK: - Allow Auto Lock
    static var allowAutoLock: String {
        switch current {
        case .english: return "Allow Auto Lock"
        case .russian: return "Разрешить автоблокировку"
        case .kazakh:  return "Автоблоктауға рұқсат ету"
        }
    }

    // MARK: - Don't Sleep During Downloads
    static var dontSleepDuringDownloads: String {
        switch current {
        case .english: return "Don't Sleep During Downloads"
        case .russian: return "Не засыпать пока идет загрузка"
        case .kazakh:  return "Жүктеу кезінде ұйықтамау"
        }
    }

    // MARK: - Stay Awake While App Active
    static var stayAwakeUntil: String {
        switch current {
        case .english: return "Don't Sleep While Active App…"
        case .russian: return "Не засыпать пока активное приложение…"
        case .kazakh:  return "Белсенді қолданба кезінде ұйықтамау…"
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
