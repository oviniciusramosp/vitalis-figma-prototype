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

private enum NativeActionsLayout {
    static let inset: CGFloat = 8
    static let tabHeight: CGFloat = 58
    static let collapsedHeight = tabHeight + inset * 2
    static let expandedHeight: CGFloat = 240
}

struct PrototypeRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("prototype.native-actions-sheet") private var nativeSheetEnabled = false
    @State private var nativeSheetSessionEnabled = UserDefaults.standard.bool(forKey: "prototype.native-actions-sheet")
    @State private var nativeSheetPresented = false
    @State private var actionsCollapsed = false
    @State private var nativeDetent: PresentationDetent = .height(NativeActionsLayout.expandedHeight)
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
                            .presentationDetents(selectedTab == .more ? [.large] : [.height(NativeActionsLayout.collapsedHeight), .height(NativeActionsLayout.expandedHeight)], selection: $nativeDetent)
                            .presentationDragIndicator(.visible)
                            .presentationBackgroundInteraction(.enabled)
                            // Preserve the system corner geometry shared by the screen, sheet and tab bar.
                            .interactiveDismissDisabled()
                            .onChange(of: nativeDetent) { _, detent in
                                if selectedTab == .today { actionsCollapsed = detent == .height(NativeActionsLayout.collapsedHeight) }
                            }
                    }
            } else {
                rootContent
            }
        }
        .preferredColorScheme(PrototypeTheme.colorScheme)
        .task(id: usesNativeSheet) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--persist-native-actions-sheet") {
                nativeSheetEnabled = true
            }
            #endif
            nativeSheetPresented = false
            guard usesNativeSheet else { return }
            // Let the previous TabView disappear before presenting its replacement.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            nativeSheetPresented = true
        }
        .onChange(of: actionsCollapsed) { _, collapsed in
            guard usesNativeSheet, selectedTab == .today else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.025)) {
                nativeDetent = .height(collapsed ? NativeActionsLayout.collapsedHeight : NativeActionsLayout.expandedHeight)
            }
        }
        .onChange(of: selectedTab) { _, tab in
            nativeDetent = tab == .more ? .large : .height(actionsCollapsed ? NativeActionsLayout.collapsedHeight : NativeActionsLayout.expandedHeight)
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
        appTabs
            .preferredColorScheme(PrototypeTheme.colorScheme)
    }

    private func deviceModal(_ device: PrototypeDevice) -> some View {
        ZStack {
            PrototypeBackdropBlur(progress: 1, style: PrototypeTheme.blurStyle)
                .overlay(Color.black.opacity(0.28))
                .accessibilityHidden(true)

            PrototypeDeviceDetailView(
                device: device,
                isSynced: syncedDevices.contains(device),
                onSync: { syncedDevices.insert(device) },
                onDismiss: { selectedDevice = nil }
            )
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .preferredColorScheme(PrototypeTheme.colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("device-modal-overlay")
        .presentationBackground(.clear)
    }

    private var appTabs: some View {
        TabView(selection: activeTabBinding) {
            Tab("Today", systemImage: "text.rectangle.page", value: .today) {
                if usesNativeSheet {
                    nativeActionsPanel
                        .toolbarVisibility(.hidden, for: .tabBar)
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
        .fullScreenCover(item: $selectedDevice) { device in
            deviceModal(device)
        }
    }

    /// Keep the controls and selection identical throughout native sheet resizing.
    /// Only the secondary glass backing fades; the sheet remains the shared surface.
    private var nativeActionsPanel: some View {
        GeometryReader { geometry in
            let expansion = min(1, max(0,
                (geometry.size.height - NativeActionsLayout.collapsedHeight)
                / (NativeActionsLayout.expandedHeight - NativeActionsLayout.collapsedHeight)
            ))
            let tabInset = sheetTabInset(in: geometry, expansion: expansion)
            Color.clear
                .overlay(alignment: .top) {
                    PrototypeActionRows(
                        onStartTest: { activeSheet = .cognitiveTest },
                        onReport: { activeSheet = .report }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: (1 - expansion) * 24)
                    .opacity(pow(expansion, 1.6))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.42), value: expansion)
                    .allowsHitTesting(!actionsCollapsed)
                    .accessibilityHidden(actionsCollapsed)
                }
                .overlay(alignment: .bottom) {
                    sheetTabs
                        .background {
                            Capsule()
                                .fill(.clear)
                                .glassEffect(.regular, in: Capsule())
                                .opacity(min(1, expansion * 3))
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: expansion)
                                .allowsHitTesting(false)
                        }
                        .padding(tabInset)
                        // Expanded sheets include the home-indicator safe area in their glass.
                        // Follow that inset continuously, without moving the collapsed controls.
                        .offset(y: geometry.safeAreaInsets.bottom * expansion)
                }
                .background {
                    PrototypeTheme.nativePanelTint
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
        }
    }

    private func sheetTabInset(in geometry: GeometryProxy, expansion: CGFloat) -> CGFloat {
        // A capsule's radius is half its height. Align its center of curvature
        // with the native sheet by subtracting that radius from the outer radius.
        var expandedInset: CGFloat = 20
        if #available(iOS 27.0, *), let radii = geometry.concentricCornerRadii(in: CGRect(
            origin: .zero,
            size: CGSize(width: geometry.size.width,
                         height: geometry.size.height + geometry.safeAreaInsets.bottom)
        )) {
            expandedInset = max(NativeActionsLayout.inset,
                               max(radii.bottomLeading, radii.bottomTrailing)
                               - NativeActionsLayout.tabHeight / 2)
        }
        return NativeActionsLayout.inset + (expandedInset - NativeActionsLayout.inset) * expansion
    }

    /// Transparent controls share the native sheet's glass instead of adding another capsule.
    private var sheetTabs: some View {
        HStack(spacing: 0) {
            collapsedTab("Today", symbol: "text.rectangle.page", tab: .today)
            collapsedTab("Exposure", symbol: "dot.radiowaves.left.and.right", tab: .exposure)
            collapsedTab("Health", symbol: "waveform.path.ecg", tab: .health)
            collapsedTab("More", symbol: "ellipsis", tab: .more)
        }
    }

    private func collapsedTab(_ title: String, symbol: String, tab: PrototypeTab) -> some View {
        Button {
            activeTabBinding.wrappedValue = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .frame(height: 26)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: NativeActionsLayout.tabHeight)
            .contentShape(Rectangle())
            .background {
                if selectedTab == tab {
                    Capsule().fill(Color.black.opacity(0.13))
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(PrototypeTheme.foreground)
        .accessibilityIdentifier("collapsed-tab-" + title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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
