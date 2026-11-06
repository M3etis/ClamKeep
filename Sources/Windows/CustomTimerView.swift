import SwiftUI

/// Custom auto-off duration: hours + minutes with steppers, live end time,
/// inline validation. Return starts, Escape cancels.
struct CustomTimerView: View {
    let onStart: (Int) -> Void
    let onCancel: () -> Void

    @State private var hours: Int
    @State private var minutes: Int
    @State private var showValidation = false
    @FocusState private var focusedField: Field?

    private enum Field { case hours, minutes }
    static let maxHours = 99

    init(initialMinutes: Int, onStart: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.onStart = onStart
        self.onCancel = onCancel
        _hours = State(initialValue: min(Self.maxHours, initialMinutes / 60))
        _minutes = State(initialValue: initialMinutes % 60)
    }

    private var total: Int { hours * 60 + minutes }

    private var endTime: String {
        let end = Date().addingTimeInterval(TimeInterval(total) * 60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L.current.rawValue)
        formatter.dateStyle = Calendar.current.isDateInToday(end) ? .none : .short
        formatter.timeStyle = .short
        return formatter.string(from: end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L.timerCustomTitle).font(DS.Typography.title)
                Text(L.timerCustomMessage)
                    .font(DS.Typography.callout)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            Grid(alignment: .leading, horizontalSpacing: DS.Spacing.m, verticalSpacing: DS.Spacing.s) {
                GridRow {
                    Text(L.timerHoursLabel).gridColumnAlignment(.trailing)
                    numberField($hours, range: 0...Self.maxHours, field: .hours)
                }
                GridRow {
                    Text(L.timerMinutesLabel)
                    numberField($minutes, range: 0...59, field: .minutes)
                }
            }

            Group {
                if total > 0 {
                    Text(L.timerTurnsOffAt(endTime))
                        .foregroundStyle(Color.dsTextSecondary)
                } else if showValidation {
                    Label(L.timerValidation, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.dsDanger)
                } else {
                    Text(" ")
                }
            }
            .font(DS.Typography.callout)
            .monospacedDigit()
            .accessibilityAddTraits(.updatesFrequently)

            HStack {
                Spacer()
                Button(L.cancelButton, action: onCancel).cancelAction()
                Button(L.timerStart, action: start).primaryAction()
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 340)
        .onAppear { focusedField = .hours }
        .onChange(of: total) { _ in showValidation = false }
    }

    private func numberField(_ value: Binding<Int>, range: ClosedRange<Int>, field: Field) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            // A text binding updates on every keystroke, so Return (the default button)
            // never starts the timer with a value the field hasn't committed yet.
            TextField("", text: Binding(
                get: { String(value.wrappedValue) },
                set: { text in
                    let number = Int(text.filter(\.isNumber).prefix(4)) ?? 0
                    value.wrappedValue = min(range.upperBound, max(range.lowerBound, number))
                }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 56)
            .focused($focusedField, equals: field)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    private func start() {
        guard total > 0 else {
            showValidation = true
            NSSound.beep()
            return
        }
        onStart(total)
    }
}
