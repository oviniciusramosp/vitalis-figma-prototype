import SwiftUI
import UIKit

@main
struct VitalisPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeRootView()
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
    @AppStorage("prototype.native-actions-sheet") private var nativeSheetEnabled = false
    @State private var nativeSheetSessionEnabled = UserDefaults.standard.bool(forKey: "prototype.native-actions-sheet")
    @State private var nativeSheetPresented = false
    @State private var actionsCollapsed = false
    @State private var nativeDetent: PresentationDetent = .height(240)
    @State private var selectedTab: PrototypeTab = .today
    @State private var activeSheet: PrototypeSheet?
    @State private var selectedDevice: PrototypeDevice?
    @State private var syncedDevices: Set<PrototypeDevice> = []
    @AppStorage("prototype.testCompleted") private var testCompleted = false
    @AppStorage("prototype.reportSubmitted") private var reportSubmitted = false

    private var usesNativeSheet: Bool {
        nativeSheetSessionEnabled || ProcessInfo.processInfo.arguments.contains("--native-actions-sheet")
    }

    var body: some View {
        Group {
            if usesNativeSheet {
                dashboard
                    .sheet(isPresented: $nativeSheetPresented) {
                        rootContent
                            .presentationDetents((selectedTab == .more || selectedDevice != nil) ? [.large] : [.height(100), .height(240)], selection: $nativeDetent)
                            .presentationDragIndicator(.visible)
                            .presentationBackground(.ultraThinMaterial)
                            .presentationBackgroundInteraction(.enabled)
                            .presentationCornerRadius(38)
                            .interactiveDismissDisabled()
                            .onChange(of: nativeDetent) { _, detent in
                                if selectedTab == .today { actionsCollapsed = detent == .height(100) }
                            }
                    }
            } else {
                rootContent
            }
        }
        .preferredColorScheme(PrototypeTheme.colorScheme)
        .task(id: usesNativeSheet) {
            nativeSheetPresented = false
            guard usesNativeSheet else { return }
            // Let the previous TabView disappear before presenting its replacement.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            nativeSheetPresented = true
        }
        .onChange(of: actionsCollapsed) { _, collapsed in
            guard usesNativeSheet, selectedTab == .today else { return }
            withAnimation(.spring(duration: 0.48, bounce: 0.09)) {
                nativeDetent = .height(collapsed ? 100 : 240)
            }
        }
        .onChange(of: selectedDevice) { _, device in
            guard usesNativeSheet else { return }
            nativeDetent = device != nil || selectedTab == .more ? .large : .height(actionsCollapsed ? 100 : 240)
        }
        .onChange(of: selectedTab) { _, tab in
            nativeDetent = tab == .more ? .large : .height(actionsCollapsed ? 100 : 240)
        }
    }

    private var dashboard: some View {
        ZStack {
            PrototypeBackground().ignoresSafeArea()
            TodayView(
                onStartTest: { activeSheet = .cognitiveTest },
                onReport: { activeSheet = .report },
                onShowDevices: { activeSheet = .devices },
                onShowDevice: { selectedDevice = $0 },
                blastIsSynced: syncedDevices.contains(.blastGauge),
                watchIsSynced: syncedDevices.contains(.appleWatch),
                actionsCollapsed: $actionsCollapsed,
                usesNativeActionsSheet: usesNativeSheet
            )
        }
    }

    private var rootContent: some View {
        ZStack {
            appTabs
                .allowsHitTesting(selectedDevice == nil)
                .accessibilityHidden(selectedDevice != nil)

            if let device = selectedDevice {
                PrototypeBackdropBlur(progress: 1, style: PrototypeTheme.blurStyle)
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
        .preferredColorScheme(PrototypeTheme.colorScheme)
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.04), value: selectedDevice)
    }

    private var appTabs: some View {
        TabView(selection: activeTabBinding) {
            Tab("Today", systemImage: "text.rectangle.page", value: .today) {
                if usesNativeSheet {
                    VStack {
                        if !actionsCollapsed {
                            PrototypeActionRows(
                                onStartTest: { activeSheet = .cognitiveTest },
                                onReport: { activeSheet = .report }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("native-actions-panel")
                    .accessibilityValue(actionsCollapsed ? "Collapsed" : "Expanded")
                } else {
                    dashboard
                }
            }
            Tab("Exposure", systemImage: "dot.radiowaves.left.and.right", value: .exposure) {
                EmptyView()
            }
            Tab("Health", systemImage: "waveform.path.ecg", value: .health) {
                EmptyView()
            }
            Tab("More", systemImage: "ellipsis", value: .more) {
                MoreView(nativeSheetEnabled: $nativeSheetEnabled, onReset: {
                    testCompleted = false
                    reportSubmitted = false
                    selectedTab = .today
                })
            }
        }
        .tint(PrototypeTheme.foreground)
        .background(InertTabSelectionGuard())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .cognitiveTest:
                CognitiveTestView(onComplete: {
                    testCompleted = true
                    activeSheet = nil
                    selectedTab = .today
                })
            case .report:
                SymptomReportView(onSubmit: {
                    reportSubmitted = true
                    selectedTab = .today
                })
            case .devices:
                DevicesView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var activeTabBinding: Binding<PrototypeTab> {
        Binding(
            get: { selectedTab },
            set: { candidate in
                guard candidate == .today || candidate == .more else { return }
                selectedTab = candidate
            }
        )
    }
}

/// Stop inactive prototype tabs before UIKit changes its selected content controller.
/// The guarded SwiftUI binding also protects keyboard and accessibility selection.
private struct InertTabSelectionGuard: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> GuardController {
        let controller = GuardController()
        controller.onAttach = { [weak coordinator = context.coordinator] controller in
            coordinator?.attach(from: controller)
        }
        return controller
    }

    func updateUIViewController(_ controller: GuardController, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(from: controller) }
    }

    static func dismantleUIViewController(_ controller: GuardController, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class GuardController: UIViewController {
        var onAttach: ((UIViewController) -> Void)?

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onAttach?(self)
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard parent != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onAttach?(self)
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            onAttach?(self)
        }
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        private weak var tabController: UITabBarController?
        private weak var forwardedDelegate: UITabBarControllerDelegate?

        func attach(from controller: UIViewController) {
            var root = controller
            while let parent = root.parent { root = parent }
            let tabs = controller.tabBarController
                ?? findTabs(in: root)
                ?? controller.view.window?.rootViewController.flatMap { findTabs(in: $0) }
            guard let tabs, tabs.delegate !== self else { return }
            tabs.view.backgroundColor = .clear
            tabController = tabs
            forwardedDelegate = tabs.delegate
            tabs.delegate = self
        }

        func detach() {
            if tabController?.delegate === self {
                tabController?.delegate = forwardedDelegate
            }
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            if let index = tabBarController.viewControllers?.firstIndex(of: viewController), index == 1 || index == 2 {
                return false
            }
            return forwardedDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
            if let index = tabBarController.tabs.firstIndex(of: tab), index == 1 || index == 2 {
                return false
            }
            return forwardedDelegate?.tabBarController?(tabBarController, shouldSelectTab: tab) ?? true
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || forwardedDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            forwardedDelegate
        }

        private func findTabs(in controller: UIViewController) -> UITabBarController? {
            if let tabs = controller as? UITabBarController { return tabs }
            for child in controller.children {
                if let tabs = findTabs(in: child) { return tabs }
            }
            return nil
        }
    }
}

#Preview {
    PrototypeRootView()
}
