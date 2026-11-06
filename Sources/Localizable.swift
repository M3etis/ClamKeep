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

    // MARK: - Actions
    static var wakeMode: String {
        switch current {
        case .english: return "Wake Mode"
        case .russian: return "Бодрствование"
        case .kazakh:  return "Ояу режим"
        }
    }

    // MARK: - Auto-off timer
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

    // MARK: - Settings
    static var launchAtLogin: String {
        switch current {
        case .english: return "Launch at Login"
        case .russian: return "Запускать при входе в систему"
        case .kazakh:  return "Жүйеге кіргенде іске қосу"
        }
    }
    static var showSystemStats: String {
        switch current {
        case .english: return "Show System Stats"
        case .russian: return "Показывать статистику"
        case .kazakh:  return "Статистиканы көрсету"
        }
    }
    static var language: String {
        switch current {
        case .english: return "Language"
        case .russian: return "Язык"
        case .kazakh:  return "Тіл"
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
    static var cancelButton: String {
        switch current {
        case .english: return "Cancel"
        case .russian: return "Отмена"
        case .kazakh:  return "Бас тарту"
        }
    }

    // MARK: - Stay Awake While App Active
    static func watchingApp(_ name: String) -> String {
        switch current {
        case .english: return "Watching: \(name)"
        case .russian: return "Слежение: \(name)"
        case .kazakh:  return "Бақылануда: \(name)"
        }
    }

    // MARK: - Setup dialog
    static var promptExplanation: String {
        switch current {
        case .english: return "ClamKeep requires administrator privileges to install its helper daemon. This daemon uses pmset to prevent your Mac from sleeping when the lid is closed."
        case .russian: return "ClamKeep требуются права администратора для установки вспомогательного компонента. Этот компонент использует pmset для предотвращения засыпания Mac при закрытой крышке."
        case .kazakh:  return "ClamKeep көмекші қызметті орнату үшін әкімші құқықтары қажет. Бұл қызмет pmset арқылы қақпақ жабылған кезде Mac ұйықтап қалуына жол бермейді."
        }
    }

    // MARK: - System metrics (compact labels for the menu header)
    static var batteryLabel: String {
        switch current {
        case .english: return "Battery"
        case .russian: return "Батарея"
        case .kazakh:  return "Батарея"
        }
    }
    static var cpuLabel: String {
        switch current {
        case .english: return "CPU"
        case .russian: return "ЦП"
        case .kazakh:  return "CPU"
        }
    }
    static var ramLabel: String {
        switch current {
        case .english: return "RAM"
        case .russian: return "ОЗУ"
        case .kazakh:  return "ЖЖҚ"
        }
    }
    static var temperatureLabel: String {
        switch current {
        case .english: return "Temp"
        case .russian: return "Темп."
        case .kazakh:  return "Темп."
        }
    }
    static var fansLabel: String {
        switch current {
        case .english: return "Fans"
        case .russian: return "Вент."
        case .kazakh:  return "Желдеткіш"
        }
    }
}

// MARK: - Interface strings

extension L {
    /// English, Russian, Kazakh — in that order.
    static func tr(_ en: String, _ ru: String, _ kk: String) -> String {
        switch current {
        case .english: return en
        case .russian: return ru
        case .kazakh:  return kk
        }
    }

    // Menu bar icon styles
    static var iconLid: String { tr("Lid", "Крышка", "Қақпақ") }
    static var iconMoon: String { tr("Moon", "Луна", "Ай") }
    static var iconBolt: String { tr("Bolt", "Энергия", "Қуат") }
    static var iconEye: String { tr("Eye", "Глаз", "Көз") }
    static var iconCoffee: String { tr("Coffee", "Кофе", "Кофе") }
    static var iconShield: String { tr("Shield", "Щит", "Қалқан") }

    // Status header
    static var statusAwake: String { tr("Mac is awake", "Mac не спит", "Mac ояу") }
    static var statusTurningOn: String { tr("Turning on…", "Включается…", "Қосылуда…") }
    static var statusSleepingNormally: String { tr("Sleeping normally", "Обычный режим сна", "Қалыпты ұйқы режимі") }
    static var statusDisplayMaySleep: String { tr("the display may sleep", "экрану можно гаснуть", "экран өше алады") }
    static var menuTurnOnWake: String { tr("Turn On Wake Mode", "Включить бодрствование", "Ояу режимді қосу") }
    static var menuTurnOffWake: String { tr("Turn Off Wake Mode", "Выключить бодрствование", "Ояу режимді өшіру") }
    static var statusHint: String { tr("Turn on to keep your Mac awake", "Включите, чтобы Mac не засыпал", "Mac ұйықтамауы үшін қосыңыз") }
    static func statusElapsed(_ time: String) -> String { tr("Active for \(time)", "Работает \(time)", "Белсенді: \(time)") }
    static func statusRemaining(_ time: String) -> String { tr("Turns off in \(time)", "Выключится через \(time)", "\(time) кейін өшеді") }

    // Menu
    static var menuAllowDisplaySleep: String { tr("Allow Display Sleep", "Разрешить сон дисплея", "Дисплей ұйқысына рұқсат ету") }
    static var menuAllowAutoLock: String { tr("Allow Auto Lock", "Разрешить автоблокировку", "Автоблоктауға рұқсат ету") }
    static var menuDownloads: String { tr("Keep Awake During Downloads", "Не засыпать во время загрузок", "Жүктеу кезінде ұйықтамау") }
    static var menuWhileAppRuns: String { tr("Keep Awake While App Runs", "Не засыпать, пока работает приложение", "Қолданба жұмыс істегенде ұйықтамау") }
    static var menuTurnOffAfter: String { tr("Turn Off After", "Выключить через", "Өшіру уақыты") }
    static var menuNever: String { tr("Never", "Никогда", "Ешқашан") }
    static func menuCustomCurrent(_ duration: String) -> String { tr("Custom (\(duration))", "Своё время (\(duration))", "Басқа уақыт (\(duration))") }
    static var menuNoApps: String { tr("No apps with windows are open", "Нет открытых приложений с окнами", "Терезесі бар қолданбалар ашылмаған") }
    static var menuNoAppsHint: String { tr("Open an app, then choose it here", "Откройте приложение и выберите его здесь", "Қолданбаны ашып, осы жерден таңдаңыз") }
    static var menuSettings: String { tr("Settings…", "Настройки…", "Баптаулар…") }
    static var menuAbout: String { tr("About ClamKeep", "О ClamKeep", "ClamKeep туралы") }
    static var menuQuit: String { tr("Quit ClamKeep", "Выйти из ClamKeep", "ClamKeep-тен шығу") }

    /// "15 min", "1 h", "1 h 30 min".
    static func duration(minutes total: Int) -> String {
        let h = total / 60, m = total % 60
        let (hs, ms) = (tr("h", "ч", "сағ"), tr("min", "мин", "мин"))
        if h == 0 { return "\(m) \(ms)" }
        if m == 0 { return "\(h) \(hs)" }
        return "\(h) \(hs) \(m) \(ms)"
    }

    // Helper
    static var helperMissingBanner: String { tr("Install the helper to keep the Mac awake with the lid closed.", "Установите помощник, чтобы Mac не засыпал с закрытой крышкой.", "Mac қақпағы жабық кезде ұйықтамауы үшін көмекшіні орнатыңыз.") }
    static var helperOutdatedBanner: String { tr("The helper needs an update.", "Помощник нужно обновить.", "Көмекшіні жаңарту қажет.") }
    static var helperInstallEllipsis: String { tr("Install…", "Установить…", "Орнату…") }
    static var helperInstalledTitle: String { tr("Helper installed", "Помощник установлен", "Көмекші орнатылған") }
    static func helperVersion(_ v: String) -> String { tr("Version \(v)", "Версия \(v)", "Нұсқа \(v)") }
    static var helperMissingTitle: String { tr("Helper isn't installed", "Помощник не установлен", "Көмекші орнатылмаған") }
    static var helperOutdatedTitle: String { tr("Helper needs an update", "Помощник нужно обновить", "Көмекшіні жаңарту қажет") }
    static var helperWhy: String { tr("It's needed to keep the Mac awake with the lid closed.", "Он нужен, чтобы Mac не засыпал с закрытой крышкой.", "Ол Mac қақпағы жабық кезде ұйықтамауы үшін қажет.") }
    static var helperInstall: String { tr("Install Helper", "Установить помощник", "Көмекшіні орнату") }
    static var helperUpdate: String { tr("Update Helper", "Обновить помощник", "Көмекшіні жаңарту") }
    static var helperReinstall: String { tr("Reinstall…", "Переустановить…", "Қайта орнату…") }
    static var helperChecking: String { tr("Checking the helper…", "Проверка помощника…", "Көмекші тексерілуде…") }
    static var helperInstalling: String { tr("Installing helper…", "Установка помощника…", "Көмекші орнатылуда…") }
    static var helperFailedTitle: String { tr("Couldn't install the helper", "Не удалось установить помощник", "Көмекшіні орнату мүмкін болмады") }
    static var helperFailedMessage: String { tr("Make sure you entered an administrator password, then try again.", "Проверьте, что введён пароль администратора, и попробуйте ещё раз.", "Әкімші құпия сөзі енгізілгенін тексеріп, қайталап көріңіз.") }
    static var helperPrepareFailed: String { tr("ClamKeep couldn't prepare the installer files.", "ClamKeep не смог подготовить файлы установки.", "ClamKeep орнату файлдарын дайындай алмады.") }
    static var tryAgain: String { tr("Try Again", "Повторить", "Қайталау") }
    static var details: String { tr("Details", "Подробности", "Толығырақ") }

    // Onboarding
    static var onboardingTitle: String { tr("Set up ClamKeep", "Настройка ClamKeep", "ClamKeep-ті баптау") }
    static var onboardingSubtitle: String { tr("A one-time step so ClamKeep can control sleep.", "Один раз, чтобы ClamKeep мог управлять сном.", "ClamKeep ұйқыны басқара алуы үшін бір рет қажет.") }
    static var onboardingPoint1: String { tr("Installs a small background helper that runs pmset.", "Ставит маленький фоновый помощник, который вызывает pmset.", "pmset шақыратын шағын фондық көмекшіні орнатады.") }
    static var onboardingPoint2: String { tr("Asks for your administrator password once.", "Пароль администратора нужен один раз.", "Әкімші құпия сөзі бір рет қажет.") }
    static var onboardingPoint3: String { tr("After that, every toggle works without a password.", "Дальше все переключения — без пароля.", "Содан кейін барлық ауыстыру құпия сөзсіз жұмыс істейді.") }
    static var notNow: String { tr("Not Now", "Не сейчас", "Қазір емес") }
    static var done: String { tr("Done", "Готово", "Дайын") }
    static var onboardingDone: String { tr("ClamKeep is ready. Turn on Wake Mode from the menu bar.", "ClamKeep готов. Включите бодрствование в строке меню.", "ClamKeep дайын. Ояу режимді мәзір жолынан қосыңыз.") }

    // Settings window
    static var tabGeneral: String { tr("General", "Основные", "Негізгі") }
    static var tabMenuBarIcon: String { tr("Menu Bar Icon", "Значок", "Белгіше") }
    static var tabAbout: String { tr("About", "О программе", "Бағдарлама туралы") }
    static var sectionStartup: String { tr("Startup and Menu", "Запуск и меню", "Іске қосу және мәзір") }
    static var sectionHelper: String { tr("Helper", "Помощник", "Көмекші") }
    static var settingsStatsHint: String { tr("Battery, CPU, RAM, temperature and fans at the top of the menu.", "Батарея, ЦП, ОЗУ, температура и вентиляторы вверху меню.", "Мәзірдің жоғарғы жағында батарея, CPU, ЖЖҚ, температура және желдеткіштер.") }
    static var settingsConfirmQuit: String { tr("Ask before quitting while Wake Mode is on", "Спрашивать перед выходом при включённом бодрствовании", "Ояу режим қосулы кезде шығу алдында сұрау") }
    static var iconPaneHint: String { tr("Outline when Wake Mode is off, filled when it's on.", "Контур — бодрствование выключено, заливка — включено.", "Контур — ояу режим өшік, толық — қосулы.") }
    static var iconTint: String { tr("Color the icon while Wake Mode is on", "Подсвечивать значок цветом при бодрствовании", "Ояу режим қосулы кезде белгішені түспен белгілеу") }
    static var iconTintHint: String { tr("Green when awake, orange when the display may sleep.", "Зелёный — Mac не спит, оранжевый — экрану разрешено гаснуть.", "Жасыл — Mac ояу, қызғылт сары — экранның өшуіне рұқсат.") }
    static var aboutTagline: String { tr("Keep your Mac awake with the lid closed.", "Mac не спит с закрытой крышкой.", "Қақпақ жабық кезде Mac ояу.") }
    static func aboutVersionLine(_ v: String, _ b: String) -> String { tr("Version \(v) (\(b))", "Версия \(v) (\(b))", "Нұсқа \(v) (\(b))") }
    static var reportIssue: String { tr("Report an Issue", "Сообщить о проблеме", "Мәселе туралы хабарлау") }

    // Custom timer
    static func timerTurnsOffAt(_ time: String) -> String { tr("Wake Mode turns off at \(time).", "Бодрствование выключится в \(time).", "Ояу режим \(time) кезінде өшеді.") }
    static var timerValidation: String { tr("Choose at least 1 minute.", "Выберите хотя бы 1 минуту.", "Кемінде 1 минут таңдаңыз.") }
    static var timerStart: String { tr("Start", "Запустить", "Бастау") }

    // Quit
    static var quitAndTurnOff: String { tr("Quit and Turn Off", "Выйти и выключить", "Шығу және өшіру") }
    static var dontAskAgain: String { tr("Don't ask again", "Больше не спрашивать", "Қайта сұрамау") }
}
