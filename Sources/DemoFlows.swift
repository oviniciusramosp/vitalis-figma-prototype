import SwiftUI
import Charts

// These screens extend the dashboard with local, demonstrative interactions.
// They do not connect to a health service, device, or clinical assessment.

struct CognitiveTestView: View {
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: TestPhase = .ready
    @State private var responseTimes: [Double] = []
    @State private var appearedAt: Date?
    @State private var countdown: Task<Void, Never>?
    @State private var tappedEarly = false

    private enum TestPhase {
        case ready, waiting, tap, roundComplete, finished
    }

    private var average: Int {
        guard !responseTimes.isEmpty else { return 0 }
        return Int(responseTimes.reduce(0, +) / Double(responseTimes.count))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DemoKicker(text: "QUICK CHECK-IN")
                    Text(phase == .finished ? "Nice work." : "A moment to focus.")
                        .font(PrototypeFont.inter(30, weight: .semibold))
                        .foregroundStyle(PrototypeTheme.foreground)
                    Text(phase == .finished
                         ? "You finished three rounds. This response time is only a demonstration of the interaction."
                         : "When the panel turns green, tap as quickly as you can. Complete three short rounds at your own pace.")
                        .font(PrototypeFont.inter(15))
                        .foregroundStyle(PrototypeTheme.muted)
                        .lineSpacing(4)

                    if phase == .ready {
                        DemoInfoCard(title: "About 30 seconds", subtitle: "Three taps. No preparation needed.", symbol: "timer")
                        primaryButton("Start test", action: startRound)
                    } else if phase == .finished {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(PrototypeTheme.success)
                                .font(PrototypeFont.inter(15, weight: .medium))
                            DemoAnimatedNumber(value: Double(average), suffix: " ms", animateOnAppear: true)
                                .font(PrototypeFont.inter(42, weight: .semibold))
                            Text("Average response time · demo interaction")
                                .font(PrototypeFont.inter(13))
                                .foregroundStyle(PrototypeTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
                        primaryButton("Finish") {
                            onComplete()
                            dismiss()
                        }
                    } else {
                        HStack {
                            DemoAnimatedNumber(value: Double(phase == .roundComplete ? responseTimes.count : min(responseTimes.count + 1, 3)), prefix: "Round ", suffix: " of 3")
                                .font(PrototypeFont.inter(14, weight: .medium))
                            Spacer()
                            ProgressView(value: Double(responseTimes.count), total: 3)
                                .tint(PrototypeTheme.success)
                                .frame(width: 100)
                        }
                        .foregroundStyle(PrototypeTheme.muted)

                        if phase == .roundComplete {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 44))
                                    .foregroundStyle(PrototypeTheme.success)
                                DemoAnimatedNumber(value: Double(Int(responseTimes.last ?? 0)), suffix: " ms", animateOnAppear: true)
                                    .font(PrototypeFont.inter(36, weight: .semibold))
                                Text("Round completed")
                                    .font(PrototypeFont.inter(14))
                                    .foregroundStyle(PrototypeTheme.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
                            primaryButton("Next round", action: startRound)
                        } else {
                            Button(action: tapPanel) {
                                VStack(spacing: 16) {
                                    Image(systemName: phase == .tap ? "hand.tap.fill" : "hourglass")
                                        .font(.system(size: 40))
                                    Text(phase == .tap ? "Tap now" : "Wait for green")
                                        .font(PrototypeFont.inter(24, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 250)
                                .foregroundStyle(phase == .tap ? Color.black : PrototypeTheme.foreground)
                                .background(phase == .tap ? PrototypeTheme.success : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(phase == .tap ? "Tap to record your response time" : "Wait until the panel turns green")
                            if tappedEarly {
                                Text("A little early. Wait for the green panel.")
                                    .font(PrototypeFont.inter(13))
                                    .foregroundStyle(PrototypeTheme.accent)
                            }
                        }
                    }

                    Text("Prototype · your result stays in this session.")
                        .font(PrototypeFont.inter(12))
                        .foregroundStyle(PrototypeTheme.muted)
                }
                .padding(24)
            }
            .background(PrototypeTheme.background)
            .navigationTitle("Cognitive test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            .onDisappear { countdown?.cancel() }
        }
        .tint(PrototypeTheme.accent)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(PrototypeFont.inter(16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .tint(PrototypeTheme.accent)
    }

    private func startRound() {
        countdown?.cancel()
        tappedEarly = false
        appearedAt = nil
        phase = .waiting
        let delays: [UInt64] = [1_600_000_000, 2_100_000_000, 1_400_000_000]
        let delay = delays[min(responseTimes.count, 2)]
        countdown = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            guard !Task.isCancelled else { return }
            appearedAt = Date()
            phase = .tap
        }
    }

    private func tapPanel() {
        guard phase == .tap, let appearedAt else {
            tappedEarly = true
            return
        }
        responseTimes.append(Date().timeIntervalSince(appearedAt) * 1_000)
        self.appearedAt = nil
        phase = responseTimes.count == 3 ? .finished : .roundComplete
    }
}

struct SymptomReportView: View {
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var intensity = 2.0
    @State private var note = ""
    @State private var submitted = false

    private let symptoms = ["Headache", "Fatigue", "Dizziness", "Nausea", "Irritation", "Other"]

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(PrototypeTheme.success)
                        Text("Check-in saved")
                            .font(PrototypeFont.inter(28, weight: .semibold))
                        Text("Your demo report is available for this session.")
                            .font(PrototypeFont.inter(15))
                            .foregroundStyle(PrototypeTheme.muted)
                            .multilineTextAlignment(.center)
                        Text(selected.sorted().joined(separator: " · "))
                            .font(PrototypeFont.inter(14, weight: .medium))
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form {
                        Section {
                            ForEach(symptoms, id: \.self) { symptom in
                                Button {
                                    if selected.contains(symptom) { selected.remove(symptom) }
                                    else { selected.insert(symptom) }
                                } label: {
                                    HStack {
                                        Text(symptom)
                                            .foregroundStyle(PrototypeTheme.foreground)
                                        Spacer()
                                        Image(systemName: selected.contains(symptom) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selected.contains(symptom) ? PrototypeTheme.accent : PrototypeTheme.muted)
                                    }
                                }
                                .accessibilityAddTraits(selected.contains(symptom) ? .isSelected : [])
                            }
                        } header: {
                            Text("How are you feeling?")
                        } footer: {
                            Text("Select everything that applies.")
                        }
                        .listRowBackground(Color.white.opacity(0.045))

                        Section("Intensity") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    DemoAnimatedNumber(value: intensity, suffix: " of 5")
                                        .font(PrototypeFont.inter(18, weight: .semibold))
                                    Spacer()
                                    Text(intensity <= 2 ? "Mild" : intensity <= 4 ? "Moderate" : "Strong")
                                        .foregroundStyle(PrototypeTheme.muted)
                                }
                                Slider(value: $intensity, in: 1...5, step: 1)
                                    .accessibilityLabel("Symptom intensity")
                                HStack {
                                    Text("Mild")
                                    Spacer()
                                    Text("Strong")
                                }
                                .font(PrototypeFont.inter(12))
                                .foregroundStyle(PrototypeTheme.muted)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white.opacity(0.045))

                        Section("Notes · optional") {
                            TextField("Anything else you want to record?", text: $note, axis: .vertical)
                                .lineLimit(3...5)
                        }
                        .listRowBackground(Color.white.opacity(0.045))

                        Section {
                            Text("Prototype report · stored only in this session.")
                                .font(PrototypeFont.inter(12))
                                .foregroundStyle(PrototypeTheme.muted)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PrototypeTheme.background)
            .font(PrototypeFont.inter(15))
            .navigationTitle("Report symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                if !submitted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save report", systemImage: "checkmark") {
                            submitted = true
                            onSubmit()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)
                    }
                }
            }
        }
        .tint(PrototypeTheme.accent)
    }
}

struct DevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bandConnected = true
    @State private var sensorConnected = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    deviceRow(name: "Helmet sensor", detail: "Demo helmet device", symbol: "sensor.fill", battery: 84, connected: $bandConnected)
                    deviceRow(name: "Apple Watch", detail: "Demo wrist device", symbol: "applewatch", battery: 40, connected: $sensorConnected, chargeAdvisory: true)
                } header: {
                    Text("Your devices")
                } footer: {
                    Text("Sample devices. Connection controls simulate a device reconnect.")
                }
                .listRowBackground(Color.white.opacity(0.045))
            }
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.background)
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .tint(PrototypeTheme.accent)
    }

    private func deviceRow(name: String, detail: String, symbol: String, battery: Int, connected: Binding<Bool>, chargeAdvisory: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(PrototypeTheme.accent)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).font(PrototypeFont.inter(17, weight: .semibold))
                    Text(detail).font(PrototypeFont.inter(13)).foregroundStyle(PrototypeTheme.muted)
                }
                Spacer()
            }
            HStack {
                Label(connected.wrappedValue ? "Connected" : "Disconnected", systemImage: connected.wrappedValue ? "circle.fill" : "circle")
                    .foregroundStyle(connected.wrappedValue ? PrototypeTheme.success : PrototypeTheme.muted)
                    .font(PrototypeFont.inter(12, weight: .medium))
                Spacer()
                Label {
                    DemoAnimatedNumber(value: Double(battery), suffix: "%")
                } icon: {
                    Image(systemName: battery <= 50 ? "battery.50percent" : "battery.75percent")
                }
                    .font(PrototypeFont.inter(13))
                    .foregroundStyle(PrototypeTheme.muted)
            }
            if chargeAdvisory {
                Label("Demo battery advisory · charge recommended", systemImage: "bolt.fill")
                    .font(PrototypeFont.inter(12, weight: .medium))
                    .foregroundStyle(PrototypeTheme.accent)
            }
            Button(connected.wrappedValue ? "Simulate disconnect" : "Simulate reconnect") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    connected.wrappedValue.toggle()
                }
            }
            .buttonStyle(.bordered)
            .font(PrototypeFont.inter(13, weight: .medium))
        }
        .padding(.vertical, 12)
    }
}

struct ExposureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var period: DemoPeriod = .week
    @State private var chartProgress = 0.0
    @State private var didAnimateChart = false

    private enum DemoPeriod: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month"
        var id: String { rawValue }
    }

    private struct Reading: Identifiable {
        let id: Int
        let label: String
        let value: Int
        // Ordinal categories keep the first four bars continuous across periods.
        var category: String { "slot-\(id)" }
    }

    private var readings: [Reading] {
        if period == .week {
            return zip(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], [26, 34, 58, 42, 31, 22, 18]).enumerated().map {
                Reading(id: $0.offset, label: $0.element.0, value: $0.element.1)
            }
        }
        return zip(["Week 1", "Week 2", "Week 3", "Week 4"], [34, 48, 31, 27]).enumerated().map {
            Reading(id: $0.offset, label: $0.element.0, value: $0.element.1)
        }
    }

    private var average: Double {
        Double(readings.reduce(0) { $0 + $1.value }) / Double(readings.count)
    }

    private var periodSelection: Binding<DemoPeriod> {
        Binding(get: { period }, set: { selectedPeriod in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
                period = selectedPeriod
            }
        })
    }

    private func animateChartEntrance() {
        guard !didAnimateChart else { return }
        didAnimateChart = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) {
            chartProgress = 1
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: periodSelection) {
                        ForEach(DemoPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)

                    VStack(alignment: .leading, spacing: 18) {
                        DemoKicker(text: "EXPOSURE OVERVIEW")
                        Text(period == .week ? "This week" : "This month")
                            .font(PrototypeFont.inter(26, weight: .semibold))
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            DemoAnimatedNumber(value: average, animateOnAppear: true)
                                .font(PrototypeFont.inter(32, weight: .semibold))
                            Text("Sample exposure index (0–100)")
                                .font(PrototypeFont.inter(13))
                                .foregroundStyle(PrototypeTheme.muted)
                        }
                        Text(period == .week ? "Sample daily readings" : "Sample weekly readings")
                            .font(PrototypeFont.inter(13))
                            .foregroundStyle(PrototypeTheme.muted)
                        Chart(readings) { reading in
                            BarMark(x: .value("Period", reading.category), y: .value("Reading", Double(reading.value) * chartProgress))
                                .foregroundStyle(PrototypeTheme.accent.gradient)
                                .cornerRadius(5)
                        }
                        .chartXScale(domain: readings.map(\.category))
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(values: [0, 25, 50, 75, 100]) {
                                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                                AxisValueLabel().foregroundStyle(PrototypeTheme.muted)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: readings.map(\.category)) { axisValue in
                                AxisValueLabel {
                                    if let category = axisValue.as(String.self),
                                       let reading = readings.first(where: { $0.category == category }) {
                                        Text(reading.label)
                                            .foregroundStyle(PrototypeTheme.muted)
                                    }
                                }
                            }
                        }
                        .frame(height: 210)
                        .accessibilityLabel("Sample exposure readings for the selected period")
                        .onAppear(perform: animateChartEntrance)
                        .onChange(of: reduceMotion) { _, isReduced in
                            if isReduced {
                                withAnimation(nil) { chartProgress = 1 }
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .listRowBackground(Color.white.opacity(0.045))
                }

                Section("Environment · sample data") {
                    DemoMetricRow(title: "Temperature", value: "23°C", symbol: "thermometer.medium")
                    DemoMetricRow(title: "Humidity", value: "42%", symbol: "humidity")
                    DemoMetricRow(title: "Noise", value: "62 dB", symbol: "waveform")
                }
                .listRowBackground(Color.white.opacity(0.045))

                Section {
                    Text("Illustrative readings for exploring the prototype.")
                        .font(PrototypeFont.inter(12))
                        .foregroundStyle(PrototypeTheme.muted)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.background)
            .navigationTitle("Exposure")
            .font(PrototypeFont.inter(15))
        }
        .tint(PrototypeTheme.accent)
    }
}

struct HealthView: View {
    let testCompleted: Bool
    let reportSubmitted: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Today’s check-ins") {
                    checkInRow(title: "Cognitive test", completed: testCompleted, pending: "Ready when you are")
                    checkInRow(title: "Symptom report", completed: reportSubmitted, pending: "No report this session")
                }
                .listRowBackground(Color.white.opacity(0.045))

                Section("Sample metrics") {
                    DemoMetricRow(title: "Heart rate", value: "72 bpm", symbol: "heart.fill")
                    DemoMetricRow(title: "Sleep", value: "7h 32m", symbol: "moon.fill")
                    DemoMetricRow(title: "Activity", value: "4,820 steps", symbol: "figure.walk")
                }
                .listRowBackground(Color.white.opacity(0.045))

                Section {
                    DemoInfoCard(title: "A little more awareness", subtitle: "Use Today to try a short test or record how you feel.", symbol: "sparkles")
                }
                .listRowBackground(Color.white.opacity(0.045))

                Section {
                    Text("Metrics are sample data. Check-in status reflects this prototype session.")
                        .font(PrototypeFont.inter(12))
                        .foregroundStyle(PrototypeTheme.muted)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.background)
            .navigationTitle("Health")
            .font(PrototypeFont.inter(15))
        }
        .tint(PrototypeTheme.accent)
    }

    private func checkInRow(title: String, completed: Bool, pending: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 24))
                .foregroundStyle(completed ? PrototypeTheme.success : PrototypeTheme.muted)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(PrototypeFont.inter(16, weight: .medium))
                Text(completed ? "Completed this session" : pending)
                    .font(PrototypeFont.inter(12))
                    .foregroundStyle(PrototypeTheme.muted)
            }
        }
        .padding(.vertical, 8)
    }
}

struct MoreView: View {
    let onReset: () -> Void

    @State private var appearance = PrototypeAppearance.shared
    @State private var confirmReset = false
    @State private var resetDone = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 18) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(PrototypeTheme.accent)
                            .frame(width: 64, height: 64)
                            .background(PrototypeTheme.accent.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Demo User").font(PrototypeFont.inter(20, weight: .semibold))
                            Text("Demo profile").font(PrototypeFont.inter(13)).foregroundStyle(PrototypeTheme.muted)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .listRowBackground(PrototypeTheme.listRow)

                Section {
                    ForEach(PrototypeThemeChoice.allCases) { theme in
                        themeOption(theme)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose the appearance for the entire prototype.")
                }
                .listRowBackground(PrototypeTheme.listRow)

                Section("About") {
                    LabeledContent("Version", value: "Prototype 1.0")
                    LabeledContent("Data", value: "Sample data")
                    Text("An interactive preview of the Vitalis interface, with local check-ins and simulated devices.")
                        .font(PrototypeFont.inter(14))
                        .foregroundStyle(PrototypeTheme.muted)
                        .padding(.vertical, 8)
                }
                .listRowBackground(PrototypeTheme.listRow)

                Section {
                    Button("Reset demo session", systemImage: "arrow.counterclockwise") {
                        confirmReset = true
                    }
                    .foregroundStyle(PrototypeTheme.accent)
                } footer: {
                    Text(resetDone ? "Demo check-ins have been reset." : "Clear the test and symptom report status to try the experience again.")
                }
                .listRowBackground(PrototypeTheme.listRow)
            }
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.background)
            .navigationTitle("More")
            .font(PrototypeFont.inter(15))
            .accessibilityIdentifier("more-screen")
            .alert("Reset this demo session?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) {
                    onReset()
                    resetDone = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The check-in status will return to its starting state.")
            }
        }
        .tint(PrototypeTheme.accent)
    }

    private func themeOption(_ theme: PrototypeThemeChoice) -> some View {
        let isSelected = appearance.selection == theme
        let selectionTraits: AccessibilityTraits = isSelected ? .isSelected : []
        return Button {
            appearance.selection = theme
        } label: {
            themeOptionLabel(theme, isSelected: isSelected)
        }
        .accessibilityLabel("\(theme.title) theme")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selectionTraits)
        .accessibilityIdentifier("theme-\(theme.rawValue)")
    }

    private func themeOptionLabel(_ theme: PrototypeThemeChoice, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: theme.symbol)
                .frame(width: 24)
                .foregroundStyle(PrototypeTheme.muted)
            Text(theme.title)
                .foregroundStyle(PrototypeTheme.foreground)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PrototypeTheme.success)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

private struct DemoKicker: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PrototypeFont.inter(11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(PrototypeTheme.accent)
    }
}

private struct DemoAnimatedNumber: View {
    let value: Double
    let prefix: String
    let suffix: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Double

    init(value: Double, prefix: String = "", suffix: String = "", animateOnAppear: Bool = false) {
        self.value = value
        self.prefix = prefix
        self.suffix = suffix
        _displayedValue = State(initialValue: animateOnAppear ? 0 : value)
    }

    var body: some View {
        Text("\(prefix)\(Int(displayedValue.rounded()))\(suffix)")
            .monospacedDigit()
            .contentTransition(.numericText(value: displayedValue))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: displayedValue)
            .onAppear { displayedValue = value }
            .onChange(of: value) { _, newValue in displayedValue = newValue }
            .transaction { transaction in
                if reduceMotion { transaction.animation = nil }
            }
    }
}

private struct DemoInfoCard: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(PrototypeTheme.accent)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(PrototypeFont.inter(16, weight: .medium))
                Text(subtitle)
                    .font(PrototypeFont.inter(13))
                    .foregroundStyle(PrototypeTheme.muted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct DemoMetricRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PrototypeTheme.accent)
                .frame(width: 24)
            Text(title).font(PrototypeFont.inter(15))
            Spacer()
            Text(value)
                .font(PrototypeFont.inter(15, weight: .medium))
                .foregroundStyle(PrototypeTheme.muted)
        }
        .padding(.vertical, 7)
    }
}
