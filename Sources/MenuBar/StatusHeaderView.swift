import AppKit

/// What the header shows. Built by the app delegate from live state.
struct StatusHeaderState: Equatable {
    enum Mode: Equatable { case off, turningOn, on, onDisplayMaySleep }

    var mode: Mode
    var subtitle: String
    /// Non-nil when the privileged helper is missing or outdated.
    var helperBanner: String?
}

/// Menu header: Wake Mode status + switch (the primary action), live system
/// metrics, and an inline banner when the helper needs installing.
final class StatusHeaderView: NSView {

    var onToggleWake: ((Bool) -> Void)?
    var onInstallHelper: (() -> Void)?

    var showsMetrics = true {
        didSet { metricsRow.isHidden = !showsMetrics || metricsRow.arrangedSubviews.isEmpty; resize() }
    }

    private let dot = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let wakeSwitch = NSSwitch()
    private let metricsRow = NSStackView()
    private let bannerRow = NSStackView()
    private let bannerLabel = NSTextField(wrappingLabelWithString: "")
    private let bannerButton = NSButton()
    private let stack = NSStackView()
    private var state: StatusHeaderState?

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: DS.Size.menuHeaderWidth, height: 60))
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Public

    func apply(_ newState: StatusHeaderState) {
        // Always resync the switch: a click while the state can't change
        // (e.g. helper missing) must snap it back.
        wakeSwitch.state = newState.mode == .off ? .off : .on
        guard newState != state else { return }
        let modeChanged = newState.mode != state?.mode
        let bannerChanged = newState.helperBanner != state?.helperBanner
        state = newState

        if modeChanged { applyMode(newState.mode) }
        subtitleLabel.stringValue = newState.subtitle

        if bannerChanged {
            bannerLabel.stringValue = newState.helperBanner ?? ""
            bannerButton.title = L.helperInstallEllipsis
            bannerRow.isHidden = newState.helperBanner == nil
            resize()
        }
        updateAccessibility()
    }

    func reloadMetrics(_ snapshot: SystemSnapshot) {
        metricsRow.arrangedSubviews.forEach {
            metricsRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for item in MetricItem.items(from: snapshot) {
            metricsRow.addArrangedSubview(Self.makeMetricCell(item))
        }
        metricsRow.isHidden = !showsMetrics || metricsRow.arrangedSubviews.isEmpty
        resize()
    }

    // MARK: - Layout

    private func build() {
        dot.wantsLayer = true
        dot.layer?.cornerRadius = DS.Size.statusDot / 2
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: DS.Size.statusDot),
            dot.heightAnchor.constraint(equalToConstant: DS.Size.statusDot),
        ])

        titleLabel.font = DS.Typography.menuHeadline
        titleLabel.textColor = DS.Palette.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = DS.Typography.menuCaption
        subtitleLabel.textColor = DS.Palette.textSecondary
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let texts = NSStackView(views: [titleLabel, subtitleLabel])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = DS.Spacing.xxs
        texts.setContentHuggingPriority(.defaultLow, for: .horizontal)
        texts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        wakeSwitch.controlSize = .small
        wakeSwitch.target = self
        wakeSwitch.action = #selector(switchChanged)
        wakeSwitch.setAccessibilityLabel(L.wakeMode)
        wakeSwitch.setContentHuggingPriority(.required, for: .horizontal)

        // Gravity areas pin the switch to the trailing edge, like Control Center modules.
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = DS.Spacing.s
        statusRow.setViews([dot, texts], in: .leading)
        statusRow.setViews([wakeSwitch], in: .trailing)

        metricsRow.orientation = .horizontal
        metricsRow.distribution = .fillEqually
        metricsRow.spacing = DS.Spacing.xs
        metricsRow.isHidden = true

        let warning = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                                 accessibilityDescription: nil) ?? NSImage())
        warning.contentTintColor = DS.Palette.warning
        warning.setContentHuggingPriority(.required, for: .horizontal)
        bannerLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        bannerLabel.textColor = DS.Palette.textSecondary
        bannerLabel.preferredMaxLayoutWidth = DS.Size.menuHeaderWidth - 2 * DS.Spacing.menuInset - 120
        bannerButton.bezelStyle = .rounded
        bannerButton.controlSize = .small
        bannerButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        bannerButton.target = self
        bannerButton.action = #selector(installTapped)
        bannerButton.setContentHuggingPriority(.required, for: .horizontal)
        bannerRow.setViews([warning, bannerLabel, bannerButton], in: .leading)
        bannerRow.orientation = .horizontal
        bannerRow.alignment = .centerY
        bannerRow.spacing = DS.Spacing.s
        bannerRow.isHidden = true

        stack.setViews([statusRow, metricsRow, bannerRow], in: .top)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = DS.Spacing.m
        stack.edgeInsets = NSEdgeInsets(top: DS.Spacing.s, left: DS.Spacing.menuInset,
                                        bottom: DS.Spacing.s, right: DS.Spacing.menuInset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let width = DS.Size.menuHeaderWidth - 2 * DS.Spacing.menuInset
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            statusRow.widthAnchor.constraint(equalToConstant: width),
            metricsRow.widthAnchor.constraint(equalToConstant: width),
            bannerRow.widthAnchor.constraint(equalToConstant: width),
        ])

        setAccessibilityElement(false)
        resize()
    }

    private func resize() {
        layoutSubtreeIfNeeded()
        let height = ceil(stack.fittingSize.height)
        setFrameSize(NSSize(width: DS.Size.menuHeaderWidth, height: height))
    }

    private func applyMode(_ mode: StatusHeaderState.Mode) {
        let color: NSColor
        switch mode {
        case .off:
            titleLabel.stringValue = L.statusSleepingNormally
            color = DS.Palette.inactive
        case .turningOn:
            titleLabel.stringValue = L.statusTurningOn
            color = DS.Palette.success.withAlphaComponent(DS.Opacity.secondary)
        case .on:
            titleLabel.stringValue = L.statusAwake
            color = DS.Palette.success
        case .onDisplayMaySleep:
            titleLabel.stringValue = L.statusAwake
            color = DS.Palette.warning
        }
        // Resolve the dynamic color for this view's appearance (the menu can differ from the app).
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dot.layer?.backgroundColor = color.cgColor
        }
        wakeSwitch.state = mode == .off ? .off : .on
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // CGColor does not follow appearance changes by itself.
        if let mode = state?.mode { applyMode(mode) }
    }

    private func updateAccessibility() {
        let parts = [titleLabel.stringValue, subtitleLabel.stringValue].filter { !$0.isEmpty }
        wakeSwitch.setAccessibilityValueDescription(parts.joined(separator: ", "))
    }

    // MARK: - Actions

    @objc private func switchChanged() {
        onToggleWake?(wakeSwitch.state == .on)
    }

    @objc private func installTapped() {
        onInstallHelper?()
    }

    // MARK: - Metrics

    private struct MetricItem {
        let symbol: String
        let value: String
        let label: String
        let tint: NSColor
        var compact = false

        static func items(from snap: SystemSnapshot) -> [MetricItem] {
            var items: [MetricItem] = []
            if let pct = snap.batteryPercent {
                let charging = snap.batteryIsCharging == true
                let level: String
                switch pct {
                case ..<10: level = "0"
                case ..<40: level = "25"
                case ..<70: level = "50"
                case ..<95: level = "75"
                default:    level = "100"
                }
                items.append(MetricItem(symbol: "battery.\(level)percent\(charging ? ".bolt" : "")",
                                        value: "\(pct)%", label: L.batteryLabel,
                                        tint: charging ? DS.Palette.success : DS.Palette.textSecondary))
            }
            if let cpu = snap.cpuPercent {
                items.append(MetricItem(symbol: "cpu", value: "\(Int(cpu.rounded()))%", label: L.cpuLabel,
                                        tint: cpu >= 80 ? DS.Palette.warning : DS.Palette.textSecondary))
            }
            if let used = snap.ramUsedBytes, let total = snap.ramTotalBytes, total > 0 {
                let pct = Int((Double(used) / Double(total) * 100).rounded())
                items.append(MetricItem(symbol: "memorychip", value: "\(pct)%", label: L.ramLabel,
                                        tint: pct >= 90 ? DS.Palette.warning : DS.Palette.textSecondary))
            }
            if let temp = snap.cpuTemperatureCelsius {
                let c = Int(temp.rounded())
                items.append(MetricItem(symbol: "thermometer.medium", value: "\(c)°", label: L.temperatureLabel,
                                        tint: c >= 80 ? DS.Palette.warning : DS.Palette.textSecondary))
            }
            let rpms = snap.fanRPMs.map { Int($0.rounded()) }
            if !rpms.isEmpty {
                items.append(MetricItem(symbol: "fanblades", value: rpms.map(String.init).joined(separator: " / "),
                                        label: L.fansLabel, tint: DS.Palette.textSecondary, compact: rpms.count > 1))
            }
            return items
        }
    }

    private static func makeMetricCell(_ item: MetricItem) -> NSView {
        // Same point size for every symbol keeps their optical size consistent.
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        icon.contentTintColor = item.tint
        icon.imageScaling = .scaleNone
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: DS.Size.metricIcon).isActive = true

        let value = NSTextField(labelWithString: item.value)
        value.font = item.compact ? DS.Typography.metricValueCompact : DS.Typography.metricValue
        value.textColor = item.tint == DS.Palette.warning ? DS.Palette.warning : DS.Palette.textPrimary
        value.alignment = .center
        value.lineBreakMode = .byTruncatingTail

        let label = NSTextField(labelWithString: item.label)
        label.font = DS.Typography.metricLabel
        label.textColor = DS.Palette.textTertiary
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail

        let column = NSStackView(views: [icon, value, label])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = DS.Spacing.xxs
        column.setAccessibilityElement(true)
        column.setAccessibilityRole(.staticText)
        column.setAccessibilityLabel("\(item.label) \(item.value)")
        return column
    }
}
