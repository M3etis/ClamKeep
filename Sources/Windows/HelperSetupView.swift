import AppKit
import SwiftUI

/// First-run setup for the privileged helper. Non-modal: closing it leaves a
/// banner in the menu header, so the user can come back later.
struct HelperSetupView: View {
    @ObservedObject var model: AppModel
    let onInstall: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            HStack(alignment: .center, spacing: DS.Spacing.l) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: DS.Size.appIconMedium, height: DS.Size.appIconMedium)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.onboardingTitle).font(.title2.weight(.semibold))
                    Text(L.onboardingSubtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                point("lock.shield", L.onboardingPoint1)
                point("key", L.onboardingPoint2)
                point("switch.2", L.onboardingPoint3)
            }

            status
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(DS.Motion.animation(), value: model.helper)

            HStack {
                Spacer()
                buttons
            }
        }
        .padding(.horizontal, DS.Spacing.xxxl)
        .padding(.top, DS.Spacing.xxxl + DS.Spacing.s)
        .padding(.bottom, DS.Spacing.xxl)
        .frame(width: 460)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Color.dsAccent)
                .frame(width: 20)
        }
        .font(DS.Typography.body)
    }

    @ViewBuilder private var status: some View {
        switch model.helper {
        case .installing:
            LoadingState(label: L.helperInstalling)
        case .installed:
            StatusBanner(kind: .success, title: L.helperInstalledTitle, message: L.onboardingDone)
        case .failed(let details):
            ErrorState(title: L.helperFailedTitle, message: L.helperFailedMessage, details: details,
                       retryTitle: L.tryAgain, detailsTitle: L.details, onRetry: onInstall)
        case .checking, .missing, .outdated:
            EmptyView()
        }
    }

    @ViewBuilder private var buttons: some View {
        switch model.helper {
        case .installed:
            Button(L.done, action: onClose).primaryAction()
        case .installing:
            Button(L.helperInstall) {}.primaryAction().disabled(true)
        case .failed:
            Button(L.notNow, action: onClose).cancelAction()
        case .checking, .missing, .outdated:
            HStack(spacing: DS.Spacing.s) {
                Button(L.notNow, action: onClose).cancelAction()
                Button(isOutdated ? L.helperUpdate : L.helperInstall, action: onInstall).primaryAction()
            }
        }
    }

    private var isOutdated: Bool {
        if case .outdated = model.helper { return true }
        return false
    }
}
