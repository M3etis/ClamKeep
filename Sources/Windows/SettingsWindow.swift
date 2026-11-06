import AppKit
import SwiftUI

/// Native preferences window: toolbar tabs, one SwiftUI pane per tab.
final class SettingsWindowController {
    enum Tab: Int, CaseIterable { case general, menuBarIcon, about }

    static let windowID = "settings"
    private let model: AppModel
    private weak var tabController: NSTabViewController?

    init(model: AppModel) {
        self.model = model
    }

    func show(_ tab: Tab = .general) {
        let window = WindowPresenter.shared.present(id: Self.windowID, title: L.tabGeneral, makeController: {
            let controller = NSTabViewController()
            controller.tabStyle = .toolbar
            controller.transitionOptions = [.allowUserInteraction, .crossfade]
            for tab in Tab.allCases {
                let host = NSHostingController(rootView: Self.pane(for: tab, model: model))
                host.sizingOptions = [.preferredContentSize]
                let item = NSTabViewItem(viewController: host)
                item.label = Self.title(for: tab)
                item.image = NSImage(systemSymbolName: Self.symbol(for: tab), accessibilityDescription: nil)
                controller.addTabViewItem(item)
            }
            tabController = controller
            return controller
        })
        window.toolbarStyle = .preference
        tabController?.selectedTabViewItemIndex = tab.rawValue
    }

    /// Tab labels are AppKit strings — refresh them after a language change.
    func relocalize() {
        guard let controller = tabController else { return }
        for (index, item) in controller.tabViewItems.enumerated() {
            if let tab = Tab(rawValue: index) { item.label = Self.title(for: tab) }
        }
        controller.view.window?.title = controller.tabViewItems[controller.selectedTabViewItemIndex].label
    }

    private static func title(for tab: Tab) -> String {
        switch tab {
        case .general: return L.tabGeneral
        case .menuBarIcon: return L.tabMenuBarIcon
        case .about: return L.tabAbout
        }
    }

    private static func symbol(for tab: Tab) -> String {
        switch tab {
        case .general: return "gearshape"
        case .menuBarIcon: return "menubar.rectangle"
        case .about: return "info.circle"
        }
    }

    private static func pane(for tab: Tab, model: AppModel) -> AnyView {
        switch tab {
        case .general: return AnyView(GeneralPane(model: model))
        case .menuBarIcon: return AnyView(MenuBarIconPane(model: model))
        case .about: return AnyView(AboutPane(model: model))
        }
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(L.sectionStartup) {
                Toggle(L.launchAtLogin, isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.commands?.setLaunchAtLogin($0) }))
                Toggle(isOn: Binding(
                    get: { model.showSystemStats },
                    set: { model.commands?.setShowSystemStats($0) })) {
                    Text(L.showSystemStats)
                    Text(L.settingsStatsHint)
                }
                Toggle(L.settingsConfirmQuit, isOn: Binding(
                    get: { model.confirmQuit },
                    set: { model.commands?.setConfirmQuit($0) }))
            }
            Section {
                Picker(L.language, selection: Binding(
                    get: { model.language },
                    set: { model.commands?.setLanguage($0) })) {
                    ForEach(Language.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
            Section(L.sectionHelper) {
                HelperStatusView(model: model)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: DS.Size.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Helper status with the next step for every state.
struct HelperStatusView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.helper {
            case .checking:
                LoadingState(label: L.helperChecking)
            case .installed(let version):
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.dsSuccess)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(L.helperInstalledTitle)
                        Text(L.helperVersion(version))
                            .font(DS.Typography.technical)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    Spacer()
                    Button(L.helperReinstall) { model.commands?.installHelper() }
                        .secondaryAction()
                }
            case .missing, .outdated:
                let outdated: Bool = { if case .outdated = model.helper { return true }; return false }()
                StatusBanner(kind: .warning,
                             title: outdated ? L.helperOutdatedTitle : L.helperMissingTitle,
                             message: L.helperWhy) {
                    Button(outdated ? L.helperUpdate : L.helperInstall) { model.commands?.installHelper() }
                        .secondaryAction()
                        .padding(.top, DS.Spacing.xs)
                }
            case .installing:
                LoadingState(label: L.helperInstalling)
            case .failed(let details):
                ErrorState(title: L.helperFailedTitle, message: L.helperFailedMessage, details: details,
                           retryTitle: L.tryAgain, detailsTitle: L.details) {
                    model.commands?.installHelper()
                }
            }
        }
        .animation(DS.Motion.animation(), value: model.helper)
    }
}

// MARK: - Menu bar icon

struct MenuBarIconPane: View {
    @ObservedObject var model: AppModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.m), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            Text(L.iconPaneHint)
                .font(DS.Typography.callout)
                .foregroundStyle(Color.dsTextSecondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: DS.Spacing.m) {
                ForEach(IconStyle.allCases, id: \.self) { style in
                    IconTile(title: style.localizedName, isSelected: model.iconStyle == style) {
                        model.commands?.setIconStyle(style)
                    } preview: {
                        HStack(spacing: DS.Spacing.l) {
                            glyph(style, .inactive)
                            glyph(style, .active)
                        }
                        .padding(.vertical, DS.Spacing.m)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            HStack(alignment: .center, spacing: DS.Spacing.m) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L.iconTint)
                    Text(L.iconTintHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer(minLength: 0)
                Toggle(L.iconTint, isOn: Binding(get: { model.tintIcon }, set: { model.commands?.setTintIcon($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: DS.Size.settingsWidth)
    }

    private func glyph(_ style: IconStyle, _ state: MenuBarIconState) -> some View {
        let image = MenuBarIcon.image(style: style, state: state, tinted: model.tintIcon)
        return Image(nsImage: image)
            .renderingMode(image.isTemplate ? .template : .original)
            .foregroundStyle(Color.dsTextPrimary)
            .accessibilityHidden(true)
    }
}

// MARK: - About

struct AboutPane: View {
    @ObservedObject var model: AppModel

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    private var version: String { info["CFBundleShortVersionString"] as? String ?? "—" }
    private var build: String { info["CFBundleVersion"] as? String ?? "—" }
    private var copyright: String { info["NSHumanReadableCopyright"] as? String ?? "" }

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: DS.Size.appIconLarge, height: DS.Size.appIconLarge)
                .accessibilityHidden(true)
            VStack(spacing: DS.Spacing.xs) {
                Text("ClamKeep").font(.title2.weight(.semibold))
                Text(L.aboutVersionLine(version, build))
                    .font(DS.Typography.callout)
                    .foregroundStyle(Color.dsTextSecondary)
                    .textSelection(.enabled)
            }
            Text(L.aboutTagline)
                .font(DS.Typography.body)
                .multilineTextAlignment(.center)
            HStack(spacing: DS.Spacing.s) {
                Button("GitHub") { open("https://github.com/M3etis/ClamKeep") }
                    .secondaryAction()
                Button(L.reportIssue) { open("https://github.com/M3etis/ClamKeep/issues") }
                    .secondaryAction()
            }
            .padding(.top, DS.Spacing.xs)
            Text(copyright)
                .font(DS.Typography.footnote)
                .foregroundStyle(Color.dsTextTertiary)
                .padding(.top, DS.Spacing.s)
        }
        .padding(DS.Spacing.xxxl)
        .frame(width: DS.Size.settingsWidth)
        .id(model.language)
    }

    private func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}
