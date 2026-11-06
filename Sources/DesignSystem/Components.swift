import AppKit
import SwiftUI

// MARK: - Buttons

/// Native button roles. One primary action per view; it also owns Return.
extension View {
    func primaryAction() -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
    }

    /// Secondary action that owns Escape (Cancel / Not Now).
    func cancelAction() -> some View {
        buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)
    }

    func secondaryAction() -> some View {
        buttonStyle(.bordered)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DS.Typography.headline)
            .foregroundStyle(Color.dsTextSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Status banner

/// Inline, non-blocking message. Replaces alerts for anything that does not
/// need an immediate decision.
struct StatusBanner<Accessory: View>: View {
    enum Kind {
        case info, success, warning, error

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return .dsAccent
            case .success: return .dsSuccess
            case .warning: return .dsWarning
            case .error: return .dsDanger
            }
        }
    }

    let kind: Kind
    let title: String
    var message: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.color)
                .font(DS.Typography.body)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title).font(DS.Typography.headline)
                if let message {
                    Text(message)
                        .font(DS.Typography.callout)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                accessory()
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                .fill(kind.color.opacity(DS.Opacity.tintedFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                .strokeBorder(kind.color.opacity(DS.Opacity.tintedStroke), lineWidth: DS.Elevation.hairline)
        )
        .accessibilityElement(children: .combine)
    }
}

extension StatusBanner where Accessory == EmptyView {
    init(kind: Kind, title: String, message: String? = nil) {
        self.init(kind: kind, title: title, message: message, accessory: { EmptyView() })
    }
}

// MARK: - Loading

struct LoadingState: View {
    let label: String

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            ProgressView().controlSize(.small)
            Text(label)
                .font(DS.Typography.body)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Error

/// Human message first, raw details on demand, always a way forward.
struct ErrorState: View {
    let title: String
    let message: String
    let details: String?
    let retryTitle: String
    let detailsTitle: String
    let onRetry: () -> Void

    @State private var showDetails = false

    var body: some View {
        StatusBanner(kind: .error, title: title, message: message) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                if let details, !details.isEmpty {
                    DisclosureGroup(detailsTitle, isExpanded: $showDetails) {
                        Text(details)
                            .font(DS.Typography.technical)
                            .foregroundStyle(Color.dsTextSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DS.Spacing.xs)
                    }
                    .font(DS.Typography.callout)
                }
                Button(retryTitle, action: onRetry)
                    .secondaryAction()
                    .controlSize(.small)
            }
            .padding(.top, DS.Spacing.xs)
        }
    }
}

// MARK: - Selectable tile

/// Grid tile with a preview and a title. Selection uses the system accent ring.
struct IconTile<Preview: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var preview: () -> Preview

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.s) {
                preview()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                            .fill(Color.dsTextPrimary.opacity(DS.Opacity.subtleFill))
                    )
                Text(title)
                    .font(DS.Typography.callout)
                    .foregroundStyle(isSelected ? Color.dsTextPrimary : Color.dsTextSecondary)
                    .lineLimit(1)
            }
            .padding(DS.Spacing.s)
            .frame(width: DS.Size.iconTile)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .fill(isHovering && !isSelected ? Color.dsTextPrimary.opacity(DS.Opacity.subtleFill) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .strokeBorder(isSelected ? Color.dsAccent : Color.dsSeparator,
                                  lineWidth: isSelected ? DS.Elevation.selectionRing : DS.Elevation.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DS.Motion.animation(DS.Motion.fast)) { isHovering = hovering }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
