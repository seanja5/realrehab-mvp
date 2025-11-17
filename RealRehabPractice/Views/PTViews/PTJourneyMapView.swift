import SwiftUI

struct PTJourneyMapView: View {
    let patientProfileId: UUID
    let planId: UUID?  // Optional: nil for new plans, non-nil for editing existing
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - State
    @State private var nodes: [LessonNode] = {
        var defaultNodes: [LessonNode] = [
            LessonNode(title: "Knee Extension", icon: .person, isLocked: false, reps: 20, restSec: 3),
            LessonNode(title: "Wall Sits", icon: .video, isLocked: false, reps: 12, restSec: 3),
            LessonNode(title: "Lunges", icon: .video, isLocked: false, reps: 12, restSec: 3),
            LessonNode(title: "Knee Extension", icon: .video, isLocked: false, reps: 12, restSec: 3),
            LessonNode(title: "Wall Sits", icon: .video, isLocked: false, reps: 12, restSec: 3),
            LessonNode(title: "Lunges", icon: .video, isLocked: false, reps: 12, restSec: 3),
            LessonNode(title: "Knee Extension", icon: .video, isLocked: false, reps: 12, restSec: 3)
        ]
        
        // Set default parameters for Wall Sits lessons
        for index in defaultNodes.indices {
            if defaultNodes[index].title.lowercased().contains("wall sits") {
                defaultNodes[index].enableReps = false
                defaultNodes[index].enableRestBetweenReps = false
                defaultNodes[index].enableSets = false
                defaultNodes[index].enableRestBetweenSets = false
                defaultNodes[index].enableKneeBendAngle = true
                defaultNodes[index].enableTimeHoldingPosition = true
                defaultNodes[index].kneeBendAngle = 120
                defaultNodes[index].timeHoldingPosition = 30
            }
        }
        
        return defaultNodes
    }()
    
    @State private var showingAddPopover = false
    @State private var addSelection = 0
    @State private var customLessonName = ""
    @State private var showingRehabOverview = false
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
    
    private let exerciseTypes = ["Knee Extension (Advanced)", "Wall Sits", "Lunges", "Squats", "Custom"]
    
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
                    // Create new LessonNode (id will be auto-generated UUID)
                    var node = LessonNode(title: dto.title, icon: iconType, isLocked: dto.isLocked, reps: dto.reps, restSec: dto.restSec)
                    
                    // Special handling for "Wall Sits" lessons
                    if dto.title.lowercased().contains("wall sits") {
                        node.enableReps = false
                        node.enableRestBetweenReps = false
                        node.enableSets = false
                        node.enableRestBetweenSets = false
                        node.enableKneeBendAngle = true
                        node.enableTimeHoldingPosition = true
                        node.kneeBendAngle = 120
                        node.timeHoldingPosition = 30
                    }
                    
                    // Note: We create new UUIDs since LessonNode.id is let and auto-generated
                    // The stored id in DTO is for reference but we generate new ones for UI
                    return node
                }
                layoutNodesZigZag()
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
            VStack(spacing: 0) {
                // Top padding to push content below sticky header (matches JourneyMapView)
                Spacer()
                    .frame(height: 40)
                
                // Journey path container
                GeometryReader { geometry in
                    ZStack {
                        // Draw the diagonal path (matches JourneyMapView)
                        if nodes.count > 1 {
                            Path { path in
                                let width = geometry.size.width
                                let startX = width * 0.3
                                var currentX = startX
                                var currentY: CGFloat = 40 // Start below the padding
                                
                                path.move(to: CGPoint(x: currentX, y: currentY))
                                
                                for (index, node) in nodes.enumerated() {
                                    // Zig-zag pattern: alternate between left and right
                                    if index > 0 {
                                        currentX = (index % 2 == 0) ? width * 0.3 : width * 0.7
                                    }
                                    currentY = node.yOffset + 40 // Offset all nodes down
                                    path.addLine(to: CGPoint(x: currentX, y: currentY))
                                }
                            }
                            .stroke(Color.brandLightBlue.opacity(0.4), lineWidth: 2)
                        }
                        
                        // Draw nodes
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            let nodeX = (index % 2 == 0) ? geometry.size.width * 0.3 : geometry.size.width * 0.7
                            
                            let displayPosition = isDragging && draggingIndex == index
                                ? CGPoint(x: nodeX + dragOffset.width, y: node.yOffset + 40 + dragOffset.height)
                                : CGPoint(x: nodeX, y: node.yOffset + 40)
                            
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
                                        guard !isDragging, draggingIndex == nil, !showingEditor, !showingRehabOverview else { return }
                                        
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
                                        if draggingIndex == nil && !showingEditor && !showingRehabOverview {
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
                            .allowsHitTesting(!showingEditor && !showingRehabOverview)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dragOffset)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: draggingIndex)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: pressedIndex)
                            .position(displayPosition)
                        }
                    }
                    .frame(height: maxHeight)
                }
                .frame(height: maxHeight)
                .padding(.horizontal, 16)
                
                // Bottom padding
                Spacer()
                    .frame(height: 0)
            }
        }
        .scrollDisabled(isDragging) // Disable scrolling while dragging
        .safeAreaInset(edge: .top) {
            // Sticky header card (matches JourneyMapView exactly)
            VStack(spacing: 0) {
                headerCard
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
            .overlay(alignment: .topTrailing) {
                // Rehab Overview popover positioned below header
                if showingRehabOverview {
                    VStack {
                        Spacer()
                            .frame(height: 80) // Height of header card
                        
                        HStack {
                            Spacer()
                            
                            RehabOverviewPopover(
                                onDismiss: {
                                    showingRehabOverview = false
                                }
                            )
                            .padding(.trailing, 16)
                        }
                    }
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
            if showingEditor {
                editorPopover
            }
            
            if showingAddPopover {
                addLessonPopover
            }
            
            // Dismiss popover when tapping outside
            if showingRehabOverview {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingRehabOverview = false
                    }
            }
        }
        .task {
            await loadPlan()
            layoutNodesZigZag()
        }
        .onAppear {
            layoutNodesZigZag()
        }
        .onChange(of: nodes.count) {
            layoutNodesZigZag()
        }
        .padding(.bottom, 20) // Extra padding for Confirm Journey button
    }
    
    private var maxHeight: CGFloat {
        // Calculate based on node count with same spacing as JourneyMapView (120pt intervals)
        CGFloat(max(nodes.count * 120 + 40, 1240))
    }
    
    // MARK: - Header Card (matches JourneyMapView exactly)
    private var headerCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lower Ex. Knee")
                    .font(.rrHeadline)
                    .foregroundStyle(.primary)
                
                Text("ACL Tear Recovery Map")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                
                Text("Phase 1")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Icons stack (matches JourneyMapView)
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
                
                // More button
                Button {
                    showingRehabOverview.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary)
                }
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
                                    addNode(
                                        with: newTitle,
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
        guard let id = selectedNodeID, let node = nodes.first(where: { $0.id == id }) else {
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
            
            // Conditionally show parameters based on what's enabled for this node
            if let id = selectedNodeID, let node = nodes.first(where: { $0.id == id }) {
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
            nodes[idx].reps = tempReps
            nodes[idx].restSec = tempRest
            nodes[idx].isLocked = tempLocked
            if nodes[idx].enableSets {
                nodes[idx].sets = tempSets
            }
            if nodes[idx].enableRestBetweenSets {
                nodes[idx].restBetweenSets = tempRestBetweenSets
            }
            if nodes[idx].enableKneeBendAngle {
                nodes[idx].kneeBendAngle = tempKneeBendAngle
            }
            if nodes[idx].enableTimeHoldingPosition {
                nodes[idx].timeHoldingPosition = tempTimeHoldingPosition
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
                layoutNodesZigZag()
                showingEditor = false
                selectedNodeID = nil
                pressedIndex = nil
            }
        }
    }
    
    // MARK: - Helper Functions
    private func layoutNodesZigZag() {
        // Match JourneyMapView spacing exactly (120pt intervals, starting at yOffset 0)
        for index in nodes.indices {
            nodes[index].yOffset = CGFloat(index) * 120
        }
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
            layoutNodesZigZag()
        }
        
        draggingIndex = nil
        dragOffset = .zero
        isDragging = false
    }
    
    private func addNode(
        with title: String,
        enableReps: Bool,
        enableRestBetweenReps: Bool,
        enableSets: Bool,
        enableRestBetweenSets: Bool,
        enableKneeBendAngle: Bool,
        enableTimeHoldingPosition: Bool
    ) {
        var newNode = LessonNode(title: title, icon: .video, isLocked: false, reps: 12, restSec: 3)
        
        // Special handling for "Wall Sits" lessons
        if title.lowercased().contains("wall sits") {
            newNode.enableReps = false
            newNode.enableRestBetweenReps = false
            newNode.enableSets = false
            newNode.enableRestBetweenSets = false
            newNode.enableKneeBendAngle = true
            newNode.enableTimeHoldingPosition = true
            newNode.kneeBendAngle = 120
            newNode.timeHoldingPosition = 30
        } else {
            newNode.enableReps = enableReps
            newNode.enableRestBetweenReps = enableRestBetweenReps
            newNode.enableSets = enableSets
            newNode.enableRestBetweenSets = enableRestBetweenSets
            newNode.enableKneeBendAngle = enableKneeBendAngle
            newNode.enableTimeHoldingPosition = enableTimeHoldingPosition
            
            // Set default values for enabled parameters
            if enableSets {
                newNode.sets = 4
            }
            if enableRestBetweenSets {
                newNode.restBetweenSets = 20
            }
            if enableKneeBendAngle {
                newNode.kneeBendAngle = 120
            }
            if enableTimeHoldingPosition {
                newNode.timeHoldingPosition = 30
            }
        }
        
        nodes.append(newNode)
        layoutNodesZigZag()
    }
}

// MARK: - Lesson Node Model
struct LessonNode: Identifiable {
    let id = UUID()
    var title: String
    var icon: IconType
    var isLocked: Bool
    var reps: Int
    var restSec: Int
    var yOffset: CGFloat = 0
    
    // New optional parameters
    var sets: Int? = nil
    var restBetweenSets: Int? = nil
    var kneeBendAngle: Int? = nil
    var timeHoldingPosition: Int? = nil
    
    // Track which parameters are enabled
    var enableReps: Bool = true
    var enableRestBetweenReps: Bool = true
    var enableSets: Bool = false
    var enableRestBetweenSets: Bool = false
    var enableKneeBendAngle: Bool = false
    var enableTimeHoldingPosition: Bool = false
    
    enum IconType {
        case person
        case video
        
        var systemName: String {
            switch self {
            case .person: return "figure.stand" // Match JourneyMapView
            case .video: return "video.fill" // Match JourneyMapView
            }
        }
    }
}

// MARK: - PT Node View (all blue, lock overlay)
struct PTNodeView: View {
    let node: LessonNode
    var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandDarkBlue) // Always blue, never gray
                .frame(width: 60 * scale, height: 60 * scale)
                .shadow(color: Color.brandDarkBlue.opacity(0.4), radius: 12, x: 0, y: 2)
            
            Image(systemName: node.icon.systemName)
                .font(.system(size: 24 * scale, weight: .medium))
                .foregroundStyle(.white)
            
            if node.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(.white)
                    .offset(x: 20 * scale, y: -20 * scale)
            }
        }
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
    }
}

// MARK: - Rehab Overview Popover
struct RehabOverviewPopover: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rehab Overview")
                .font(.rrTitle)
            
            HStack(alignment: .top) {
                Text("Number of phases:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("4")
                    .font(.rrBody)
            }
            
            HStack(alignment: .top) {
                Text("Phase 1:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("8 lessons")
                    .font(.rrBody)
            }
            
            HStack(alignment: .top) {
                Text("Phase 2:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("20 lessons")
                    .font(.rrBody)
            }
            
            HStack(alignment: .top) {
                Text("Phase 3:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("22 lessons")
                    .font(.rrBody)
            }
            
            HStack(alignment: .top) {
                Text("Phase 4:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("10 lessons")
                    .font(.rrBody)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .frame(width: 320)
        .onTapGesture {
            // Prevent tap from propagating
        }
    }
}

