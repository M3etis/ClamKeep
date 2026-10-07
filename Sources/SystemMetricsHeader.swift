import AppKit

/// Modern metrics dashboard shown as the menu header: one section per sensor (icon + value + label).
/// No card fill — sections sit directly on the menu background, equal width across the row.
final class SystemMetricsHeader: NSView {

    private let stack = NSStackView()

    static let preferredWidth: CGFloat = 380
    static let preferredHeight: CGFloat = 80

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.preferredWidth, height: Self.preferredHeight)
    }

    func reload(with snap: SystemSnapshot) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let items = Self.metricItems(from: snap)
        isHidden = items.isEmpty
        guard !items.isEmpty else { return }

        for item in items {
            stack.addArrangedSubview(makeCell(symbol: item.symbol, value: item.value, label: item.label, tint: item.tint, valuePointSize: item.valuePointSize))
        }

        // Keep the item view tall enough for labels so the menu never clips them.
        needsLayout = true
        layoutSubtreeIfNeeded()
        let fitted = ceil(stack.fittingSize.height + 24)
        frame.size.height = max(fitted, Self.preferredHeight)
    }

    // MARK: - Metric model

    private struct MetricItem {
        let symbol: String
        let value: String
        let label: String
        let tint: NSColor
        var valuePointSize: CGFloat = 14
    }

    private static func metricItems(from snap: SystemSnapshot) -> [MetricItem] {
        var items: [MetricItem] = []

        if let pct = snap.batteryPercent {
            let charging = snap.batteryIsCharging == true
            let symbol: String
            switch pct {
            case ..<10:   symbol = charging ? "battery.0percent.bolt" : "battery.0percent"
            case ..<40:   symbol = charging ? "battery.25percent.bolt" : "battery.25percent"
            case ..<70:   symbol = charging ? "battery.50percent.bolt" : "battery.50percent"
            case ..<95:   symbol = charging ? "battery.75percent.bolt" : "battery.75percent"
            default:      symbol = charging ? "battery.100percent.bolt" : "battery.100percent"
            }
            items.append(MetricItem(
                symbol: symbol,
                value: "\(pct)%",
                label: L.batteryLabel,
                tint: charging ? .systemGreen : .secondaryLabelColor
            ))
        }

        if let cpu = snap.cpuPercent {
            items.append(MetricItem(
                symbol: "cpu",
                value: "\(Int(cpu.rounded()))%",
                label: L.cpuLabel,
                tint: cpu >= 80 ? .systemOrange : .secondaryLabelColor
            ))
        }

        if let used = snap.ramUsedBytes, let total = snap.ramTotalBytes, total > 0 {
            let pct = Int((Double(used) / Double(total) * 100).rounded())
            items.append(MetricItem(
                symbol: "memorychip",
                value: "\(pct)%",
                label: L.ramLabel,
                tint: pct >= 90 ? .systemOrange : .secondaryLabelColor
            ))
        }

        if let temp = snap.cpuTemperatureCelsius {
            let c = Int(temp.rounded())
            items.append(MetricItem(
                symbol: "thermometer",
                value: "\(c)°",
                label: L.temperatureLabel,
                tint: c >= 80 ? .systemOrange : .secondaryLabelColor
            ))
        }

        let rpms = snap.fanRPMs.map { Int($0.rounded()) }
        if !rpms.isEmpty {
            let value = rpms.map(String.init).joined(separator: " / ")
            items.append(MetricItem(
                symbol: "fanblades",
                value: value,
                label: L.fansLabel,
                tint: .secondaryLabelColor,
                // Multi-fan readouts need more horizontal room; smaller type keeps one line.
                valuePointSize: rpms.count > 1 ? 11 : 14
            ))
        }

        return items
    }

    // MARK: - Cell

    private func makeCell(symbol: String, value: String, label: String, tint: NSColor, valuePointSize: CGFloat) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        icon.contentTintColor = tint
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 15),
            icon.heightAnchor.constraint(equalToConstant: 15),
        ])

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: valuePointSize, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .center
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentHuggingPriority(.required, for: .vertical)
        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let nameLabel = NSTextField(labelWithString: label)
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .tertiaryLabelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentHuggingPriority(.required, for: .vertical)
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let column = NSStackView(views: [icon, valueLabel, nameLabel])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 3
        column.distribution = .fill
        column.setContentCompressionResistancePriority(.required, for: .vertical)
        return column
    }
}
