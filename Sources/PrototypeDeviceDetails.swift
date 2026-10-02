import SwiftUI

enum PrototypeDevice: String, CaseIterable, Identifiable, Hashable {
    case blastGauge
    case appleWatch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blastGauge: "Blast Gauge"
        case .appleWatch: "Apple Watch"
        }
    }

    var detailAssetName: String {
        switch self {
        case .blastGauge: "blast-device-modal"
        case .appleWatch: "device-two"
        }
    }

    var initialLastSynced: String {
        switch self {
        case .blastGauge: "2 days ago"
        case .appleWatch: "3 hours ago"
        }
    }

    var unsyncedMessage: String {
        switch self {
        case .blastGauge:
            "Your Blast Gauge hasn’t synced. Today’s blast data may be incomplete."
        case .appleWatch:
            "Your Apple Watch hasn’t synced. Refresh its connection status."
        }
    }

    // Sample battery status; syncing does not change this value.
    var batteryPercentage: Int? {
        self == .appleWatch ? 38 : 90
    }
}

/// Card content only. Its presenter supplies the centered placement and backdrop.
/// onSync reports completion of a local simulation, never a real device connection.
struct PrototypeDeviceDetailView: View {
    let device: PrototypeDevice
    let isSynced: Bool
    let onSync: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSyncing = false
    @State private var simulationCompleted = false
    @State private var progress = 0.0
    @State private var syncTask: Task<Void, Never>?

    init(
        device: PrototypeDevice,
        isSynced: Bool,
        onSync: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.device = device
        self.isSynced = isSynced
        self.onSync = onSync
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Image(device.detailAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168.58, height: 168.58)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                if hasSynced {
                    Text("Connected")
                        .font(.headline)
                        .foregroundStyle(PrototypeTheme.success)
                        .accessibilityIdentifier("device-connection-status")
                }

                Text(message)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PrototypeTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("device-sync-status")

                Text("Last synced: \(hasSynced ? "Just now" : device.initialLastSynced).")
                    .font(.body)
                    .foregroundStyle(PrototypeTheme.muted)
                    .accessibilityIdentifier("device-last-synced")

                if let batteryPercentage = device.batteryPercentage {
                    batteryStatus(batteryPercentage)
                }

                if isSyncing {
                    ProgressView(value: progress)
                        .tint(.blue)
                        .animation(reduceMotion ? nil : .linear(duration: 0.3), value: progress)
                        .accessibilityLabel("Simulated sync progress")
                        .accessibilityValue("\(Int(progress * 100)) percent")
                        .accessibilityIdentifier("device-sync-progress")
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 24)

            actions

        }
        .padding(14)
        .frame(maxWidth: 302)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular.tint(PrototypeTheme.modalTint), in: .rect(cornerRadius: 30))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("device-detail-\(device.rawValue)")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: hasSynced)
        .onDisappear(perform: cancelSimulation)
    }

    private var hasSynced: Bool {
        isSynced || simulationCompleted
    }

    private var message: String {
        if hasSynced { return "Your \(device.displayName) is up to date." }
        if isSyncing { return "Syncing \(device.displayName)…" }
        return device.unsyncedMessage
    }

    private func batteryStatus(_ percentage: Int) -> some View {
        HStack {
            Text("Battery")
                .font(.subheadline)
            Spacer()
            Text("\(percentage)%")
                .font(.title3.weight(.semibold))
                .foregroundStyle(percentage > 50 ? PrototypeTheme.success : PrototypeTheme.accent)
                .monospacedDigit()
        }
        .foregroundStyle(PrototypeTheme.foreground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery")
        .accessibilityValue("\(percentage) percent")
        .accessibilityIdentifier("device-battery")
    }

    @ViewBuilder
    private var actions: some View {
        if hasSynced {
            Button(action: onDismiss) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.blue)
                .accessibilityIdentifier("device-done")
        } else {
            HStack(spacing: 8) {
                Button(action: simulateSync) {
                    Text(isSyncing ? "Syncing…" : "Sync Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.blue)
                .disabled(isSyncing)
                .accessibilityIdentifier("device-sync-now")

                Button(action: onDismiss) {
                    Text("Ignore")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(PrototypeTheme.foreground)
                    .accessibilityIdentifier("device-ignore")
            }
        }
    }

    private func simulateSync() {
        guard !isSyncing && !hasSynced else { return }
        isSyncing = true
        progress = 0
        syncTask = Task { @MainActor in
            for step in 1...4 {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                progress = Double(step) / 4
            }
            simulationCompleted = true
            isSyncing = false
            syncTask = nil
            onSync()
        }
    }

    private func cancelSimulation() {
        syncTask?.cancel()
        syncTask = nil
        isSyncing = false
        progress = 0
    }
}
