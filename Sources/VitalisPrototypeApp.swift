import SwiftUI

@main
struct VitalisPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeRootView()
                .preferredColorScheme(.dark)
        }
    }
}

private enum PrototypeTab: Hashable {
    case today, exposure, health, more
}

private enum PrototypeSheet: String, Identifiable {
    case cognitiveTest, report, devices
    var id: String { rawValue }
}

struct PrototypeRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: PrototypeTab = .today
    @State private var activeSheet: PrototypeSheet?
    @State private var selectedDevice: PrototypeDevice?
    @State private var syncedDevices: Set<PrototypeDevice> = []
    @AppStorage("prototype.testCompleted") private var testCompleted = false
    @AppStorage("prototype.reportSubmitted") private var reportSubmitted = false

    var body: some View {
        ZStack {
            appTabs
                .allowsHitTesting(selectedDevice == nil)
                .accessibilityHidden(selectedDevice != nil)

            if let device = selectedDevice {
                PrototypeBackdropBlur(progress: 1, style: .dark)
                    .overlay(Color.black.opacity(0.28))
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                PrototypeDeviceDetailView(
                    device: device,
                    isSynced: syncedDevices.contains(device),
                    onSync: { syncedDevices.insert(device) },
                    onDismiss: { selectedDevice = nil }
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.04), value: selectedDevice)
    }

    private var appTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "text.rectangle.page", value: .today) {
                ZStack {
                    PrototypeBackground().ignoresSafeArea()
                    TodayView(
                        onStartTest: { activeSheet = .cognitiveTest },
                        onReport: { activeSheet = .report },
                        onShowDevices: { activeSheet = .devices },
                        onShowDevice: { selectedDevice = $0 },
                        blastIsSynced: syncedDevices.contains(.blastGauge),
                        watchIsSynced: syncedDevices.contains(.appleWatch)
                    )
                }
            }
            Tab("Exposure", systemImage: "dot.radiowaves.left.and.right", value: .exposure) {
                ExposureView()
            }
            Tab("Health", systemImage: "waveform.path.ecg", value: .health) {
                HealthView(testCompleted: testCompleted, reportSubmitted: reportSubmitted)
            }
            Tab("More", systemImage: "ellipsis", value: .more) {
                MoreView(onReset: {
                    testCompleted = false
                    reportSubmitted = false
                    selectedTab = .today
                })
            }
        }
        .tint(.white)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .cognitiveTest:
                CognitiveTestView(onComplete: {
                    testCompleted = true
                    activeSheet = nil
                    selectedTab = .health
                })
            case .report:
                SymptomReportView(onSubmit: {
                    reportSubmitted = true
                    selectedTab = .health
                })
            case .devices:
                DevicesView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    PrototypeRootView().preferredColorScheme(.dark)
}
