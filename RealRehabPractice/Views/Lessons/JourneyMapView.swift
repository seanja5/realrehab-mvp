import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject var router: Router
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var vm = JourneyMapViewModel()
    
    @State private var showCallout = false
    @State private var showCompletedLessonPopover = false
    @State private var showPhaseGoals = false
    @State private var selectedNodeIndex: Int?
    @State private var showLockedPopup = false
    @State private var pressedNodeIndex: Int? = nil
    @State private var activePhaseId: Int = 1
    @State private var headerBottomGlobal: CGFloat = 0
    @State private var lastKnownPhasePositions: [Int: CGFloat] = [:]
    @State private var offlineRefreshMessage: String? = nil
    private var activePhase: Int { activePhaseId }
    
    // Computed property for dynamic height (phase clearance built into node yOffsets)
    private var maxHeight: CGFloat {
        let lastY = vm.nodes.last?.yOffset ?? 0
        return max(ACLJourneyModels.contentHeight(lastNodeYOffset: lastY), 400)
    }

    /// Phase boundary Y positions in GeometryReader content space; updates when nodes change.
    private var phaseBoundaries: (phase2: CGFloat, phase3: CGFloat, phase4: CGFloat) {
        ACLJourneyModels.phaseBoundaryYs(
            nodes: vm.nodes.map { ($0.yOffset, $0.phase) },
            nodeContentOffset: 40,
            maxHeight: maxHeight
        )
    }
    
    // Get selected node title for popup
    private var selectedNodeTitle: String {
        guard let index = selectedNodeIndex, index < vm.nodes.count else {
            return "Lesson"
        }
        return vm.nodes[index].title.isEmpty ? "Lesson" : vm.nodes[index].title
    }

    // Get selected node description for popup (nil for benchmarks)
    private var selectedNodeDescription: String? {
        ACLJourneyModels.lessonDescription(for: selectedNodeTitle)
    }
    
    // Check if selected node is first unlocked lesson
    private var isFirstUnlockedLesson: Bool {
        guard let index = selectedNodeIndex, index < vm.nodes.count, !vm.nodes[index].isLocked else {
            return false
        }
        // Find first unlocked lesson index
        if let firstUnlockedIndex = vm.nodes.firstIndex(where: { !$0.isLocked }) {
            return index == firstUnlockedIndex
        }
        return false
    }
    
    private var journeyScrollContent: some View {
        ScrollView {
                    VStack(spacing: 0) {
                        OfflineStaleBanner(showBanner: !networkMonitor.isOnline && vm.showOfflineBanner)
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 1)
                                .phaseHeaderPosition(phase: 1)
                            Color.clear.frame(height: max(0, phaseBoundaries.phase2 - 1))
                            Color.clear.frame(height: 1)
                                .phaseHeaderPosition(phase: 2)
                            Color.clear.frame(height: max(0, phaseBoundaries.phase3 - phaseBoundaries.phase2 - 1))
                            Color.clear.frame(height: 1)
                                .phaseHeaderPosition(phase: 3)
                            Color.clear.frame(height: max(0, phaseBoundaries.phase4 - phaseBoundaries.phase3 - 1))
                            Color.clear.frame(height: 1)
                                .phaseHeaderPosition(phase: 4)
                            Color.clear.frame(height: max(0, maxHeight + 60 - phaseBoundaries.phase4 - 1))
                        }
                        .scrollTargetLayout()
                        
                        // Visible content
                        VStack(spacing: 0) {
                            Spacer().frame(height: 0)
                            GeometryReader { geometry in
                            ZStack(alignment: .topLeading) {
                                Path { path in
                                    let width = geometry.size.width
                                    let startY: CGFloat = 40
                                    for (index, node) in vm.nodes.enumerated() {
                                        let indexInPhase = index - (vm.nodes[0..<index].lastIndex(where: { $0.phase != node.phase }).map { $0 + 1 } ?? 0)
                                        let nodeX = safeNodeX(indexInPhase: indexInPhase, width: width)
                                        let nodeY = node.yOffset + startY
                                        if !isValid(nodeX) || !isValid(nodeY) { continue }
                                        let point = CGPoint(x: nodeX, y: nodeY)
                                        let isPhaseBoundary = index > 0 && node.phase != vm.nodes[index - 1].phase
                                        if isPhaseBoundary {
                                            path.move(to: point)
                                        } else if index == 0 {
                                            path.move(to: point)
                                        } else {
                                            path.addLine(to: point)
                                        }
                                    }
                                }
                                .stroke(Color.brandLightBlue.opacity(0.4), lineWidth: 2)
                                
                                ForEach(Array(vm.nodes.enumerated()), id: \.element.id) { index, node in
                                    let indexInPhase = index - (vm.nodes[0..<index].lastIndex(where: { $0.phase != node.phase }).map { $0 + 1 } ?? 0)
                                    let nodeX = safeNodeX(indexInPhase: indexInPhase, width: geometry.size.width)
                                    let posY = node.yOffset + 40
                                    let safeX = isValid(nodeX) ? nodeX : (geometry.size.width / 2)
                                    let safeY = isValid(posY) ? posY : 40
                                    Button {
                                        selectedNodeIndex = index
                                        if node.isLocked {
                                            showLockedPopup = true
                                        } else if vm.lessonProgress[node.id]?.isCompleted == true {
                                            showCompletedLessonPopover = true
                                        } else {
                                            showCallout = true
                                        }
                                    } label: {
                                        NodeView(node: node, isPressed: pressedNodeIndex == index, progress: vm.lessonProgress[node.id])
                                    }
                                    .buttonStyle(LessonBubbleButtonStyle(pressedNodeIndex: $pressedNodeIndex, index: index))
                                    .position(x: safeX, y: safeY)
                                }
                                
                                // Phase separator overlays (positions from node layout)
                                PhaseSeparatorView(phase: 2, timeline: ACLPhase.phase(from: 2).timeline)
                                    .position(x: geometry.size.width / 2, y: phaseBoundaries.phase2)
                                PhaseSeparatorView(phase: 3, timeline: ACLPhase.phase(from: 3).timeline)
                                    .position(x: geometry.size.width / 2, y: phaseBoundaries.phase3)
                                PhaseSeparatorView(phase: 4, timeline: ACLPhase.phase(from: 4).timeline)
                                    .position(x: geometry.size.width / 2, y: phaseBoundaries.phase4)
                            }
                            .frame(height: maxHeight)
                        }
                        .frame(height: maxHeight)
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 60)
                        }
                    }
                    .frame(height: 40 + maxHeight + 60)
                    .onPreferenceChange(PhaseHeaderPreferenceKey.self) { positions in
                        for (k, v) in positions { lastKnownPhasePositions[k] = v }
                        if !positions.isEmpty {
                            activePhaseId = JourneyMapPhaseHeader.activePhase(
                                thresholdY: headerBottomGlobal,
                                phasePositions: positions
                            )
                        }
                    }
                }
                .coordinateSpace(name: JourneyMapPhaseHeader.coordinateSpaceName)
                    }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.isLoading {
                ProgressView("Loading plan...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.95))
            } else if vm.nodes.isEmpty {
                VStack {
                    Spacer()
                    Text("You have not been assigned a rehab plan yet")
                        .font(.rrTitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                journeyScrollContent
            }
            
            PatientTabBar(
                selected: .journey,
                onSelect: { tab in
                    switch tab {
                    case .dashboard:
                        router.goWithoutAnimation(.ptDetail)
                    case .journey:
                        break
                    case .settings:
                        router.goWithoutAnimation(.patientSettings)
                    }
                },
                onAddTapped: {
                    router.go(.pairDevice)
                }
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onPreferenceChange(StickyHeaderBottomPreferenceKey.self) { value in
            headerBottomGlobal = value
            if !lastKnownPhasePositions.isEmpty {
                activePhaseId = JourneyMapPhaseHeader.activePhase(
                    thresholdY: value,
                    phasePositions: lastKnownPhasePositions
                )
            }
        }
        .rrPageBackground()
        .safeAreaInset(edge: .top) {
            if vm.isLinkedToPT == true && !vm.isLoading && !vm.nodes.isEmpty {
                headerCard
                    .reportHeaderBottom()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Journey Map")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
        .overlay {
                if showPhaseGoals {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showPhaseGoals = false }
                        .overlay(alignment: .topTrailing) {
                            VStack {
                                Spacer().frame(height: 100)
                                HStack {
                                    Spacer()
                                    PhaseGoalsPopover(phase: activePhase, onDismiss: { showPhaseGoals = false })
                                        .padding(.trailing, 16)
                                }
                                Spacer()
                            }
                        }
                }
                if showCompletedLessonPopover, let idx = selectedNodeIndex, idx < vm.nodes.count {
                    let node = vm.nodes[idx]
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showCompletedLessonPopover = false
                            selectedNodeIndex = nil
                        }
                        .overlay(alignment: .top) {
                            VStack(spacing: 16) {
                                Text("Completed \(node.title.isEmpty ? "Lesson" : node.title)")
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                
                                if let desc = ACLJourneyModels.lessonDescription(for: node.title) {
                                    Text(desc)
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Text("\(node.reps) reps, \(node.restSec) sec rest")
                                    .font(.rrCaption)
                                    .foregroundStyle(.secondary)
                                
                                PrimaryButton(title: "View Results") {
                                    router.go(.completion(lessonId: node.id))
                                    showCompletedLessonPopover = false
                                    selectedNodeIndex = nil
                                }
                                .padding(.horizontal, 24)
                                
                                SecondaryButton(title: "Close") {
                                    showCompletedLessonPopover = false
                                    selectedNodeIndex = nil
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                            )
                            .padding(.top, 140)
                        }
                }
                
                if showCallout {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { 
                            showCallout = false
                            selectedNodeIndex = nil
                        }
                        .overlay(alignment: .top) {
                            VStack(spacing: 16) {
                                Text(selectedNodeTitle)
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                
                                if let desc = selectedNodeDescription {
                                    Text(desc)
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                PrimaryButton(title: "Go!") {
                                    guard let idx = selectedNodeIndex, idx < vm.nodes.count else {
                                        showCallout = false
                                        selectedNodeIndex = nil
                                        return
                                    }
                                    let node = vm.nodes[idx]
                                    if node.title.lowercased().contains("knee extension") {
                                        router.go(.directionsView1(reps: node.reps, restSec: node.restSec, lessonId: node.id))
                                    } else {
                                        router.go(.directionsView1(reps: nil, restSec: nil, lessonId: node.id))
                                    }
                                    showCallout = false
                                    selectedNodeIndex = nil
                                }
                                .padding(.horizontal, 24)
                                
                                SecondaryButton(title: "Close") {
                                    showCallout = false
                                    selectedNodeIndex = nil
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                            )
                            .padding(.top, 140)
                        }
                }
                
                if showLockedPopup {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { 
                            showLockedPopup = false
                            selectedNodeIndex = nil
                        }
                        .overlay(alignment: .top) {
                            VStack(spacing: 16) {
                                Text(selectedNodeTitle)
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                
                                if let desc = selectedNodeDescription {
                                    Text(desc)
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Text("Locked")
                                    .font(.rrBody)
                                    .foregroundStyle(.secondary)
                                
                                Text("You haven't yet reached this level")
                                    .font(.rrCaption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                SecondaryButton(title: "Close") {
                                    showLockedPopup = false
                                    selectedNodeIndex = nil
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                            )
                            .padding(.top, 140)
                        }
                    }
        }
        .task {
            await vm.load(forceRefresh: false)
        }
        .refreshable {
            await vm.load(forceRefresh: true)
        }
        .alert("Offline", isPresented: .constant(offlineRefreshMessage != nil)) {
            Button("OK") {
                offlineRefreshMessage = nil
            }
        } message: {
            Text(offlineRefreshMessage ?? "")
        }
        .bluetoothPopupOverlay()
    }
    
    // MARK: - Header Card (only shown when plan is loaded)
    private var headerCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACL Tear Recovery Map")
                    .font(.rrHeadline)
                    .foregroundStyle(.primary)
                Text("Phase \(activePhase)")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                Text(ACLPhase.phase(from: activePhase).timeline)
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showPhaseGoals.toggle()
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .overlay(alignment: .bottomTrailing) {
            StreakIconView(state: vm.streakState)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
    }
    
    private func isValid(_ v: CGFloat) -> Bool {
        !(v.isNaN || v.isInfinite)
    }
    
    /// indexInPhase: 0 = first node of phase (starts center), then S-curve flows left/right as index increases.
    private func safeNodeX(indexInPhase: Int, width: CGFloat) -> CGFloat {
        let bubbleRadius: CGFloat = ACLJourneyModels.lessonBubbleRadius
        let innerMargin: CGFloat = 55
        let minX = bubbleRadius + innerMargin
        let maxX = max(minX, width - bubbleRadius - innerMargin)
        let usable = max(0, maxX - minX)
        let amplitude = usable / 2
        let center = minX + amplitude
        let period: CGFloat = 9.0
        let t = CGFloat(indexInPhase) / period * (2 * .pi)
        var x = center + amplitude * sin(t)
        x += min(8, amplitude * 0.15) * sin(t * 2 + 0.7)
        x = min(max(x, minX), maxX)
        if x.isNaN || x.isInfinite { x = center }
        return x
    }
    
    private func NodeView(node: JourneyNode, isPressed: Bool = false, progress: LessonProgressInfo? = nil) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Group {
                    if node.nodeType == .benchmark {
                        Image(systemName: "star.fill")
                            .font(.system(size: 66))
                            .foregroundStyle(node.isLocked ? Color.gray.opacity(0.5) : Color.brandDarkBlue)
                            .shadow(color: (node.isLocked ? Color.gray : Color.brandDarkBlue).opacity(0.3), radius: 12, x: 0, y: 2)
                    } else {
                        let isCompleted = progress?.isCompleted ?? false
                        GlossyLessonBubbleBackground(
                            baseColor: isCompleted ? Color.green : Color.brandDarkBlue,
                            isLocked: node.isLocked,
                            isPressed: isPressed,
                            isCompleted: isCompleted
                        )
                    }
                }
                
                if node.nodeType == .lesson {
                    Image(systemName: ACLJourneyModels.lessonIconSystemName(for: node.title))
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .offset(y: isPressed ? 6 : 0)
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: isPressed)
                }
                
                if node.nodeType == .benchmark && node.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.gray)
                        .offset(x: 30, y: -30)
                }
            }
            
            if node.nodeType == .lesson, let prog = progress, prog.isInProgress {
                HStack(spacing: 4) {
                    Text("(Paused)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                    ProgressView(value: prog.repsTarget > 0 ? Double(prog.repsCompleted) / Double(prog.repsTarget) : 0)
                        .progressViewStyle(.linear)
                        .tint(prog.repsCompleted > 0 ? Color.brandDarkBlue : Color.clear)
                        .frame(width: 24, height: 4)
                }
                .offset(x: 2, y: -8)
            }
        }
    }
}

// MARK: - Button style for lesson bubbles – uses Button's built-in scroll delay so ScrollView can scroll when user drags.
// Delays clearing pressed state so the release animation always plays fully, even on quick taps.
private struct LessonBubbleButtonStyle: ButtonStyle {
    @Binding var pressedNodeIndex: Int?
    let index: Int
    /// Minimum time to show release animation (matches GlossyLessonBubbleBackground spring)
    private let releaseAnimationDuration: TimeInterval = 0.25

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    pressedNodeIndex = index
                } else {
                    // Delay clear so the release animation always plays fully, even on quick taps
                    let releasedIndex = index
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(releaseAnimationDuration))
                        if pressedNodeIndex == releasedIndex {
                            pressedNodeIndex = nil
                        }
                    }
                }
            }
    }
}

