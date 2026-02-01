import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject var router: Router
    @StateObject private var vm = JourneyMapViewModel()
    
    @State private var showCallout = false
    @State private var showPhaseGoals = false
    @State private var selectedNodeIndex: Int?
    @State private var showLockedPopup = false
    @State private var activePhaseId: Int = 1
    @State private var headerBottomGlobal: CGFloat = 0
    @State private var lastKnownPhasePositions: [Int: CGFloat] = [:]
    private var activePhase: Int { activePhaseId }
    
    // Computed property for dynamic height
    private var maxHeight: CGFloat {
        CGFloat(max(vm.nodes.count * 120 + 40, 400))
    }

    /// Phase boundary Y positions in GeometryReader content space; updates when nodes change.
    private var phaseBoundaries: (phase2: CGFloat, phase3: CGFloat, phase4: CGFloat) {
        ACLJourneyModels.phaseBoundaryYs(
            nodes: vm.nodes.map { ($0.yOffset, $0.phase) },
            nodeContentOffset: 40,
            gapBelowLastNode: 60,
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.nodes.isEmpty {
                VStack {
                    Spacer()
                    Text("You have not been assigned a rehab plan yet")
                        .font(.rrTitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 1)
                                .phaseHeaderPosition(phase: 1)
                            Color.clear.frame(height: max(0, 40 + phaseBoundaries.phase2 - 1))
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
                            Spacer().frame(height: 40)
                            GeometryReader { geometry in
                            ZStack(alignment: .topLeading) {
                                Path { path in
                                    let width = geometry.size.width
                                    var currentX = width * 0.3
                                    var currentY: CGFloat = 40
                                    
                                    for (index, node) in vm.nodes.enumerated() {
                                        currentX = (index % 2 == 0) ? width * 0.3 : width * 0.7
                                        currentY = node.yOffset + 40
                                        let point = CGPoint(x: currentX, y: currentY)
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
                                    let nodeX = (index % 2 == 0) ? geometry.size.width * 0.3 : geometry.size.width * 0.7
                                    
                                    NodeView(node: node)
                                        .position(x: nodeX, y: node.yOffset + 40)
                                        .onTapGesture {
                                            selectedNodeIndex = index
                                            if node.isLocked {
                                                showLockedPopup = true
                                            } else {
                                                showCallout = true
                                            }
                                        }
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
                                        router.go(.directionsView1(reps: node.reps, restSec: node.restSec))
                                    } else {
                                        router.go(.directionsView1(reps: nil, restSec: nil))
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
            await vm.load()
        }
        .bluetoothPopupOverlay()
    }
    
    // MARK: - Header Card (sticky, dynamic phase)
    private var headerCard: some View {
        VStack(spacing: 0) {
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
        }
        .padding(16)
    }
    
    private func NodeView(node: JourneyNode) -> some View {
        ZStack {
            Group {
                if node.nodeType == .benchmark {
                    Image(systemName: "star.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(node.isLocked ? Color.gray.opacity(0.5) : Color.brandDarkBlue)
                        .shadow(color: (node.isLocked ? Color.gray : Color.brandDarkBlue).opacity(0.3), radius: 12, x: 0, y: 2)
                } else {
                    Circle()
                        .fill(node.isLocked ? Color.gray.opacity(0.3) : Color.brandDarkBlue)
                        .frame(width: 60, height: 60)
                        .shadow(color: node.isLocked ? Color.gray.opacity(0.2) : Color.brandDarkBlue.opacity(0.4), radius: 12, x: 0, y: 2)
                }
            }
            
            if node.nodeType == .lesson {
                Image(systemName: node.isLocked ? "lock.fill" : "video.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            if node.nodeType == .benchmark && node.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                    .offset(x: 20, y: -20)
            }
        }
    }
    
}


