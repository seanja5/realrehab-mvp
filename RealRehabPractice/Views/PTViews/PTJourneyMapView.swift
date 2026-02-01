import SwiftUI

struct PTJourneyMapView: View {
    let patientProfileId: UUID
    let planId: UUID?  // Optional: nil for new plans, non-nil for editing existing
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - State
    @State private var nodes: [LessonNode] = ACLJourneyModels.defaultACLPlanNodes()
    
    @State private var showingAddPopover = false
    @State private var addSelection = 0
    @State private var addPhaseSelection: Int = 0  // 0 = "Select", 1-4 = Phase 1-4
    @State private var customLessonName = ""
    @State private var scrollContentMinY: CGFloat = 0  // scroll offset when adding (for insert position)
    @State private var showingPhaseGoals = false
    @State private var activePhaseId: Int = 1
    @State private var headerBottomGlobal: CGFloat = 0
    @State private var lastKnownPhasePositions: [Int: CGFloat] = [:]
    @State private var selectedNodeID: UUID? = nil
    @State private var showingEditor = false
    @State private var tempReps: Int = 12
    @State private var tempRest: Int = 3
    @State private var tempLocked: Bool = false
    @State private var tempSets: Int = 4
    @State private var tempRestBetweenSets: Int = 20
    @State private var tempKneeBendAngle: Int = 120
    @State private var tempTimeHoldingPosition: Int = 30
    @State private var enableReps = true
    @State private var enableRestBetweenReps = true
    @State private var enableSets = false
    @State private var enableRestBetweenSets = false
    @State private var enableKneeBendAngle = false
    @State private var enableTimeHoldingPosition = false
    
    // Drag state
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var pressedIndex: Int? = nil // Index of bubble that is "pressed"/enlarged by tap
    
    private var exerciseTypes: [String] { ACLJourneyModels.allExerciseNamesForPicker }
    private var activePhase: Int { activePhaseId }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            content
            
            // Confirm Journey button fixed at bottom
            VStack(spacing: 0) {
                Spacer()
                PrimaryButton(
                    title: isLoading ? "Saving..." : "Confirm Journey",
                    isDisabled: isLoading
                ) {
                    Task {
                        await confirmJourney()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(Color.white)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func confirmJourney() async {
        guard let ptProfileId = session.ptProfileId else {
            errorMessage = "PT profile not available"
            print("❌ PTJourneyMapView.confirmJourney: ptProfileId is nil")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await RehabService.saveACLPlan(ptProfileId: ptProfileId, patientProfileId: patientProfileId, nodes: nodes)
            
            // Navigate back to PatientDetailView with the patientProfileId
            router.go(.ptPatientDetail(patientProfileId: patientProfileId))
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PTJourneyMapView.confirmJourney error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Load Plan
    private func loadPlan() async {
        guard let planId = planId else {
            // No planId means creating new plan - use default nodes
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            guard let plan = try await RehabService.fetchPlan(planId: planId) else {
                errorMessage = "Plan not found"
                isLoading = false
                return
            }
            
            // Convert PlanNodeDTO array to LessonNode array
            if let savedNodes = plan.nodes {
                nodes = savedNodes.map { dto in
                    let iconType: LessonNode.IconType = dto.icon == "person" ? .person : .video
                    let nodeType: JourneyNodeType = (dto.nodeType == "benchmark") ? .benchmark : .lesson
                    let phase = max(1, min(4, dto.phase ?? 1))
                    var node = LessonNode(title: dto.title, icon: iconType, isLocked: dto.isLocked, reps: dto.reps, restSec: dto.restSec, nodeType: nodeType, phase: phase)
                    if node.nodeType == .lesson && node.title.lowercased().contains("wall sit") {
                        node.enableReps = false
                        node.enableRestBetweenReps = false
                        node.enableSets = false
                        node.enableRestBetweenSets = false
                        node.enableKneeBendAngle = true
                        node.enableTimeHoldingPosition = true
                        node.kneeBendAngle = 120
                        node.timeHoldingPosition = 30
                    }
                    return node
                }
                ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
                print("✅ PTJourneyMapView: loaded \(nodes.count) nodes from plan")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PTJourneyMapView.loadPlan error: \(error)")
        }
        
        isLoading = false
    }
    
    private var content: some View {
        ScrollView {
            ZStack(alignment: .top) {
                Color.clear
                    .frame(height: 0)
                    .frame(maxWidth: .infinity)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named(JourneyMapPhaseHeader.coordinateSpaceName)).minY
                            )
                        }
                    )
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
                        // Draw the diagonal path (matches JourneyMapView)
                        if nodes.count > 1 {
                            Path { path in
                                let width = geometry.size.width
                                let startY: CGFloat = 40
                                for (index, node) in nodes.enumerated() {
                                    let indexInPhase = index - (nodes[0..<index].lastIndex(where: { $0.phase != node.phase }).map { $0 + 1 } ?? 0)
                                    let nodeX = safeNodeX(indexInPhase: indexInPhase, width: width)
                                    let nodeY = node.yOffset + startY
                                    if !isValid(nodeX) || !isValid(nodeY) { continue }
                                    let point = CGPoint(x: nodeX, y: nodeY)
                                    let isPhaseBoundary = index > 0 && node.phase != nodes[index - 1].phase
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
                        }
                        
                        // Draw nodes
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            let indexInPhase = index - (nodes[0..<index].lastIndex(where: { $0.phase != node.phase }).map { $0 + 1 } ?? 0)
                            let nodeX = safeNodeX(indexInPhase: indexInPhase, width: geometry.size.width)
                            let baseY = node.yOffset + 40
                            let safeX = isValid(nodeX) ? nodeX : (geometry.size.width / 2)
                            let safeY = isValid(baseY) ? baseY : 40
                            let displayPosition = isDragging && draggingIndex == index
                                ? CGPoint(x: safeX + dragOffset.width, y: safeY + dragOffset.height)
                                : CGPoint(x: safeX, y: safeY)
                            
                            PTNodeView(
                                node: node,
                                scale: (draggingIndex == index || pressedIndex == index) ? 1.2 : 1.0
                            )
                            .contentShape(Rectangle()) // Ensure full hit area
                            
                            // 1) TAP: enlarge, open editor, then shrink when editor closes
                            .highPriorityGesture(
                                TapGesture()
                                    .onEnded {
                                        // Ignore taps during active drag or when another overlay is showing
                                        guard !isDragging, draggingIndex == nil, !showingEditor, !showingPhaseGoals else { return }
                                        
                                        pressedIndex = index
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            // Visual enlarge handled by scale binding
                                        }
                                        beginEdit(node: node)
                                    }
                            )
                            
                            // 2) LONG PRESS (0.3s) + DRAG: enter drag mode and move node
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.3)
                                    .onEnded { _ in
                                        // Start drag mode
                                        if draggingIndex == nil && !showingEditor && !showingPhaseGoals {
                                            draggingIndex = index
                                            isDragging = true
                                            pressedIndex = nil
                                        }
                                    }
                                    .simultaneously(with:
                                        DragGesture(minimumDistance: 1)
                                            .onChanged { value in
                                                guard isDragging, draggingIndex == index else { return }
                                                dragOffset = value.translation
                                            }
                                            .onEnded { value in
                                                if isDragging, draggingIndex == index {
                                                    handleDragEnd(from: index, translation: value.translation, geometry: geometry)
                                                }
                                                // Reset safety
                                                isDragging = false
                                                draggingIndex = nil
                                                dragOffset = .zero
                                            }
                                    )
                            )
                            .allowsHitTesting(!showingEditor && !showingPhaseGoals)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dragOffset)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: draggingIndex)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: pressedIndex)
                            .position(displayPosition)
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
                
                Spacer().frame(height: 0)
                }
            }
            .frame(height: 40 + maxHeight + 60)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollContentMinY = $0 }
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
        .onPreferenceChange(StickyHeaderBottomPreferenceKey.self) { value in
            headerBottomGlobal = value
            if !lastKnownPhasePositions.isEmpty {
                activePhaseId = JourneyMapPhaseHeader.activePhase(
                    thresholdY: value,
                    phasePositions: lastKnownPhasePositions
                )
            }
        }
        .scrollDisabled(isDragging) // Disable scrolling while dragging
        .safeAreaInset(edge: .top) {
            // Sticky header card (matches JourneyMapView exactly)
            VStack(spacing: 0) {
                headerCard
                    .reportHeaderBottom()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                // Floating "+" button positioned below header
                HStack {
                    Spacer()
                    Button {
                        showingAddPopover = true
                        addPhaseSelection = activePhaseId  // Default to current phase
                        // Reset add form
                        addSelection = 0
                        customLessonName = ""
                        enableReps = true
                        enableRestBetweenReps = true
                        enableSets = false
                        enableRestBetweenSets = false
                        enableKneeBendAngle = false
                        enableTimeHoldingPosition = false
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.brandDarkBlue))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 12)
                }
            }
        }
        .rrPageBackground()
        .navigationTitle("Journey Map")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .overlay {
            if showingPhaseGoals {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showingPhaseGoals = false }
                    .overlay(alignment: .topTrailing) {
                        VStack {
                            Spacer().frame(height: 100)
                            HStack {
                                Spacer()
                                PhaseGoalsPopover(
                                    phase: activePhase,
                                    onDismiss: { showingPhaseGoals = false }
                                )
                                .padding(.trailing, 16)
                            }
                            Spacer()
                        }
                    }
            }
            if showingEditor {
                editorPopover
            }
            
            if showingAddPopover {
                addLessonPopover
            }
            
            // Dismiss popover when tapping outside
            if showingPhaseGoals {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingPhaseGoals = false
                    }
            }
        }
        .task {
            await loadPlan()
            ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
        }
        .onAppear {
            ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
        }
        .onChange(of: nodes.count) {
            ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
        }
        .padding(.bottom, 20) // Extra padding for Confirm Journey button
    }
    
    private var maxHeight: CGFloat {
        let lastY = nodes.last?.yOffset ?? 0
        return max(ACLJourneyModels.contentHeight(lastNodeYOffset: lastY), 1240)
    }

    /// Phase boundary Y positions in GeometryReader content space; updates when nodes change.
    private var phaseBoundaries: (phase2: CGFloat, phase3: CGFloat, phase4: CGFloat) {
        ACLJourneyModels.phaseBoundaryYs(
            nodes: nodes.map { ($0.yOffset, $0.phase) },
            nodeContentOffset: 40,
            maxHeight: maxHeight
        )
    }
    
    // MARK: - Header Card (sticky, dynamic phase)
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
                showingPhaseGoals.toggle()
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
    }
    
    // MARK: - Add Lesson Popover
    private var addLessonPopover: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring()) {
                    showingAddPopover = false
                }
            }
            .overlay {
                VStack(spacing: 0) {
                    // Spacer to push content below navbar
                    Spacer()
                        .frame(height: 100) // Space for navbar title area
                    
                    HStack {
                        Spacer()
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Add a Lesson")
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                
                                // Exercise Type Dropdown
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Exercise Type")
                                        .font(.rrBody)
                                    
                                    Picker("Exercise Type", selection: $addSelection) {
                                        ForEach(0..<exerciseTypes.count, id: \.self) { index in
                                            Text(exerciseTypes[index]).tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(14)
                                    .background(Color(uiColor: .secondarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                
                                // Phase # selection
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Phase #")
                                        .font(.rrBody)
                                    
                                    Picker("Phase #", selection: $addPhaseSelection) {
                                        Text("Select").tag(0)
                                        Text("Phase 1").tag(1)
                                        Text("Phase 2").tag(2)
                                        Text("Phase 3").tag(3)
                                        Text("Phase 4").tag(4)
                                    }
                                    .pickerStyle(.menu)
                                    .padding(14)
                                    .background(Color(uiColor: .secondarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                
                                // Custom Lesson Text Field - only show when "Custom" is selected
                                if addSelection == exerciseTypes.count - 1 { // "Custom" is last item
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Custom Lesson")
                                            .font(.rrBody)
                                        
                                        TextField("Enter custom lesson name", text: $customLessonName)
                                            .font(.rrBody)
                                            .padding(14)
                                            .background(Color(uiColor: .secondarySystemFill))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                                
                                // Types of Parameters
                                Text("Types of Parameters")
                                    .font(.rrHeadline)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Number of repetitions")
                                            .font(.rrBody)
                                        Spacer()
                                        Toggle("", isOn: $enableReps)
                                            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
                                    }
                                    
                                    HStack {
                                        Text("Time in between repetitions")
                                            .font(.rrBody)
                                        Spacer()
                                        Toggle("", isOn: $enableRestBetweenReps)
                                            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
                                    }
                                    
                                    HStack {
                                        Text("Number of sets")
                                            .font(.rrBody)
                                        Spacer()
                                        Toggle("", isOn: $enableSets)
                                            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
                                    }
                                    
                                    HStack {
                                        Text("Rest in between sets (sec)")
                                            .font(.rrBody)
                                        Spacer()
                                        Toggle("", isOn: $enableRestBetweenSets)
                                            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
                                    }
                                    
                                    HStack {
                                        Text("Knee bend angle (degrees)")
                                            .font(.rrBody)
                                        Spacer()
                                        Toggle("", isOn: $enableKneeBendAngle)
                                            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
                                    }
                                    
                                    HStack {
                                        Text("Time holding position (sec)")
                                            .font(.rrBody)
                                        Spacer()
                                        Toggle("", isOn: $enableTimeHoldingPosition)
                                            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
                                    }
                                }
                                
                                PrimaryButton(title: "Add Lesson") {
                                    let newTitle = (addSelection == exerciseTypes.count - 1 && !customLessonName.isEmpty) ? customLessonName : exerciseTypes[addSelection]
                                    let phase = addPhaseSelection >= 1 ? addPhaseSelection : activePhaseId
                                    addNode(
                                        with: newTitle,
                                        phase: phase,
                                        enableReps: enableReps,
                                        enableRestBetweenReps: enableRestBetweenReps,
                                        enableSets: enableSets,
                                        enableRestBetweenSets: enableRestBetweenSets,
                                        enableKneeBendAngle: enableKneeBendAngle,
                                        enableTimeHoldingPosition: enableTimeHoldingPosition
                                    )
                                    withAnimation(.spring()) {
                                        showingAddPopover = false
                                    }
                                }
                                
                                SecondaryButton(title: "Close") {
                                    withAnimation(.spring()) {
                                        showingAddPopover = false
                                    }
                                }
                            }
                            .padding(20)
                        }
                        .frame(maxWidth: 340)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                        )
                        
                        Spacer()
                    }
                    
                    // Spacer to push content above Confirm Journey button
                    Spacer()
                        .frame(height: 120) // Space for Confirm Journey button
                }
            }
    }
    
    // MARK: - Editor Popover (centered)
    private var editorPopover: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring()) {
                    showingEditor = false
                    selectedNodeID = nil
                    pressedIndex = nil
                }
            }
            .overlay {
                let enabledParamCount = enabledParameterCount
                let needsScrolling = enabledParamCount >= 4
                
                Group {
                    if needsScrolling {
                        ScrollView {
                            editorContent
                        }
                        .frame(maxWidth: 340, maxHeight: 600)
                    } else {
                        editorContent
                            .frame(maxWidth: 340)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                )
            }
    }
    
    // Computed property to count enabled parameters
    private var enabledParameterCount: Int {
        guard let id = selectedNodeID, let node = nodes.first(where: { $0.id == id }), node.nodeType == .lesson else {
            return 0
        }
        var count = 0
        if node.enableReps { count += 1 }
        if node.enableRestBetweenReps { count += 1 }
        if node.enableSets { count += 1 }
        if node.enableRestBetweenSets { count += 1 }
        if node.enableKneeBendAngle { count += 1 }
        if node.enableTimeHoldingPosition { count += 1 }
        return count
    }
    
    // Editor content view
    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedNodeTitle)
                .font(.rrTitle)
                .foregroundStyle(.primary)
            
            if let desc = selectedNodeDescription {
                Text(desc)
                    .font(.rrBody)
                    .foregroundStyle(.secondary)
            }
            
            // Benchmarks: title only, lock, remove. Lessons: full parameters.
            if let id = selectedNodeID, let node = nodes.first(where: { $0.id == id }), node.nodeType == .lesson {
                if node.enableReps {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set number of repetitions")
                            .font(.rrBody)
                        
                        HStack(spacing: 8) {
                            Stepper(value: $tempReps, in: 1...200) {
                                Text("\(tempReps)")
                                    .font(.rrBody)
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                }
                
                if node.enableRestBetweenReps {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time in between repetitions (sec)")
                            .font(.rrBody)
                        
                        HStack(spacing: 8) {
                            Stepper(value: $tempRest, in: 0...120) {
                                Text("\(tempRest)")
                                    .font(.rrBody)
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                }
                if node.enableSets {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of sets")
                            .font(.rrBody)
                        
                        HStack(spacing: 8) {
                            Stepper(value: $tempSets, in: 1...50) {
                                Text("\(tempSets)")
                                    .font(.rrBody)
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                }
                
                if node.enableRestBetweenSets {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest in between sets (sec)")
                            .font(.rrBody)
                        
                        HStack(spacing: 8) {
                            Stepper(value: $tempRestBetweenSets, in: 0...300) {
                                Text("\(tempRestBetweenSets)")
                                    .font(.rrBody)
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                }
                
                if node.enableKneeBendAngle {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Knee bend angle (degrees)")
                            .font(.rrBody)
                        
                        HStack(spacing: 8) {
                            Stepper(value: $tempKneeBendAngle, in: 0...180) {
                                Text("\(tempKneeBendAngle)")
                                    .font(.rrBody)
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                }
                
                if node.enableTimeHoldingPosition {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time holding position (sec)")
                            .font(.rrBody)
                        
                        HStack(spacing: 8) {
                            Stepper(value: $tempTimeHoldingPosition, in: 0...300) {
                                Text("\(tempTimeHoldingPosition)")
                                    .font(.rrBody)
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                }
            }
            
            Toggle(isOn: $tempLocked) {
                Text("Lock Lesson?")
                    .font(.rrBody)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
            
            PrimaryButton(title: "Set Parameters") {
                commitEdit()
            }
            
            Button {
                removeSelectedNode()
            } label: {
                Text("Remove Lesson")
                    .font(.rrBody)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red, lineWidth: 1)
                    )
            }
        }
        .padding(20)
    }
    
    // MARK: - Computed Properties
    private var selectedNodeTitle: String {
        if let id = selectedNodeID,
           let node = nodes.first(where: { $0.id == id }) {
            return node.title
        }
        return "Lesson"
    }

    private var selectedNodeDescription: String? {
        ACLJourneyModels.lessonDescription(for: selectedNodeTitle)
    }
    
    // MARK: - Helper Functions for Editor
    private func nodeIndex(for id: UUID) -> Int? {
        nodes.firstIndex(where: { $0.id == id })
    }
    
    private func beginEdit(node: LessonNode) {
        tempReps = node.reps
        tempRest = node.restSec
        tempLocked = node.isLocked
        tempSets = node.sets ?? 4
        tempRestBetweenSets = node.restBetweenSets ?? 20
        tempKneeBendAngle = node.kneeBendAngle ?? 120
        tempTimeHoldingPosition = node.timeHoldingPosition ?? 30
        selectedNodeID = node.id
        withAnimation(.spring()) {
            showingEditor = true
        }
    }
    
    private func commitEdit() {
        if let id = selectedNodeID,
           let idx = nodeIndex(for: id) {
            nodes[idx].isLocked = tempLocked
            if nodes[idx].nodeType == .lesson {
                nodes[idx].reps = tempReps
                nodes[idx].restSec = tempRest
                if nodes[idx].enableSets { nodes[idx].sets = tempSets }
                if nodes[idx].enableRestBetweenSets { nodes[idx].restBetweenSets = tempRestBetweenSets }
                if nodes[idx].enableKneeBendAngle { nodes[idx].kneeBendAngle = tempKneeBendAngle }
                if nodes[idx].enableTimeHoldingPosition { nodes[idx].timeHoldingPosition = tempTimeHoldingPosition }
            }
        }
        withAnimation(.spring()) {
            showingEditor = false
            selectedNodeID = nil
            pressedIndex = nil
        }
    }
    
    private func removeSelectedNode() {
        if let id = selectedNodeID,
           let idx = nodeIndex(for: id) {
            withAnimation(.spring()) {
                nodes.remove(at: idx)
                ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
                showingEditor = false
                selectedNodeID = nil
                pressedIndex = nil
            }
        }
    }
    
    // MARK: - Helper Functions
    private func isValid(_ v: CGFloat) -> Bool {
        !(v.isNaN || v.isInfinite)
    }
    
    /// indexInPhase: 0 = first node of phase (starts left), then S-curve flows right as index increases.
    private func safeNodeX(indexInPhase: Int, width: CGFloat) -> CGFloat {
        let bubbleRadius: CGFloat = 30
        let innerMargin: CGFloat = 22
        let minX = bubbleRadius + innerMargin
        let maxX = max(minX, width - bubbleRadius - innerMargin)
        let usable = max(0, maxX - minX)
        let amplitude = usable / 2
        let center = minX + amplitude
        let period: CGFloat = 9.0
        let t = CGFloat(indexInPhase) / period * (2 * .pi) - .pi / 2
        var x = center + amplitude * sin(t)
        x += min(8, amplitude * 0.15) * sin(t * 2 + 0.7)
        x = min(max(x, minX), maxX)
        if x.isNaN || x.isInfinite { x = center }
        return x
    }
    
    private func handleDragEnd(from index: Int, translation: CGSize, geometry: GeometryProxy) {
        let finalY = nodes[index].yOffset + 40 + translation.height // Account for padding offset
        
        // Find nearest index based on Y position
        let targetY = finalY - 40 // Remove padding offset to get yOffset
        var nearestIndex = index
        
        for (i, node) in nodes.enumerated() {
            if abs(node.yOffset - targetY) < abs(nodes[nearestIndex].yOffset - targetY) {
                nearestIndex = i
            }
        }
        
        if nearestIndex != index {
            reorder(from: index, to: nearestIndex)
        } else {
            draggingIndex = nil
            dragOffset = .zero
            isDragging = false
        }
    }
    
    private func reorder(from: Int, to: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let node = nodes.remove(at: from)
            nodes.insert(node, at: to)
            ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
        }
        
        draggingIndex = nil
        dragOffset = .zero
        isDragging = false
    }
    
    private func addNode(
        with title: String,
        phase: Int,
        enableReps: Bool,
        enableRestBetweenReps: Bool,
        enableSets: Bool,
        enableRestBetweenSets: Bool,
        enableKneeBendAngle: Bool,
        enableTimeHoldingPosition: Bool
    ) {
        let newNode = LessonNode.lesson(title: title, phase: phase)
        var added = newNode
        if !title.lowercased().contains("wall sit") {
            added.enableReps = enableReps
            added.enableRestBetweenReps = enableRestBetweenReps
            added.enableSets = enableSets
            added.enableRestBetweenSets = enableRestBetweenSets
            added.enableKneeBendAngle = enableKneeBendAngle
            added.enableTimeHoldingPosition = enableTimeHoldingPosition
            if enableSets { added.sets = 4 }
            if enableRestBetweenSets { added.restBetweenSets = 20 }
            if enableKneeBendAngle { added.kneeBendAngle = 120 }
            if enableTimeHoldingPosition { added.timeHoldingPosition = 30 }
        }
        let insertIndex: Int
        if phase == activePhaseId {
            let targetContentY = scrollContentMinY + 200
            let targetYOffset = targetContentY - 40
            let firstInPhase = nodes.firstIndex(where: { $0.phase == phase }) ?? nodes.count
            let lastInPhase = nodes.lastIndex(where: { $0.phase == phase }) ?? -1
            if firstInPhase > lastInPhase {
                insertIndex = firstInPhase
            } else {
                let indicesInPhase = Array(firstInPhase...lastInPhase)
                let idealIndex = indicesInPhase.min(by: { abs(nodes[$0].yOffset - targetYOffset) < abs(nodes[$1].yOffset - targetYOffset) }) ?? lastInPhase
                insertIndex = min(idealIndex + 1, lastInPhase + 1)
            }
        } else {
            // Insert at end of selected phase
            let lastInPhase = nodes.lastIndex(where: { $0.phase == phase })
            insertIndex = (lastInPhase ?? -1) + 1
        }
        nodes.insert(added, at: insertIndex)
        ACLJourneyModels.layoutNodesZigZag(nodes: &nodes)
    }
}

// MARK: - Phase separator (horizontal line + "Phase N")
struct PhaseSeparatorView: View {
    let phase: Int
    let timeline: String
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(height: 1)
            Text("Phase \(phase)")
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Phase goals popover (replaces schedule/overview)
struct PhaseGoalsPopover: View {
    let phase: Int
    let onDismiss: () -> Void
    
    private var goals: [String] {
        ACLPhase.phase(from: phase).goals
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase \(phase) Goals")
                .font(.rrTitle)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(goals, id: \.self) { goal in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.rrBody)
                        Text(goal)
                            .font(.rrBody)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            
            Button("Close") { onDismiss() }
                .font(.rrCaption)
        }
        .padding(16)
        .frame(width: 340, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .onTapGesture { }
    }
}

// MARK: - PT Node View (circle for lessons, star for benchmarks)
struct PTNodeView: View {
    let node: LessonNode
    var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Group {
                if node.nodeType == .benchmark {
                    Image(systemName: "star.fill")
                        .font(.system(size: 44 * scale))
                        .foregroundStyle(Color.brandDarkBlue)
                        .shadow(color: Color.brandDarkBlue.opacity(0.4), radius: 12, x: 0, y: 2)
                } else {
                    Circle()
                        .fill(Color.brandDarkBlue)
                        .frame(width: 60 * scale, height: 60 * scale)
                        .shadow(color: Color.brandDarkBlue.opacity(0.4), radius: 12, x: 0, y: 2)
                }
            }
            
            if node.nodeType == .lesson {
                Image(systemName: node.icon.systemName)
                    .font(.system(size: 24 * scale, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            if node.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(node.nodeType == .benchmark ? .gray : .white)
                    .offset(x: 20 * scale, y: -20 * scale)
            }
        }
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
    }
}


