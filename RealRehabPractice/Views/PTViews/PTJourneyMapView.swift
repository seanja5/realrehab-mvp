import SwiftUI

struct PTJourneyMapView: View {
    @EnvironmentObject var router: Router
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // TODO: Receive patient_profile_id from route
    private var patientProfileId: UUID? = nil
    
    // MARK: - State
    @State private var nodes: [LessonNode] = [
        LessonNode(title: "Knee Extension", icon: .person, isLocked: false, reps: 20, restSec: 3),
        LessonNode(title: "Wall Sits", icon: .video, isLocked: false, reps: 12, restSec: 3),
        LessonNode(title: "Lunges", icon: .video, isLocked: false, reps: 12, restSec: 3),
        LessonNode(title: "Knee Extension", icon: .video, isLocked: false, reps: 12, restSec: 3),
        LessonNode(title: "Wall Sits", icon: .video, isLocked: false, reps: 12, restSec: 3),
        LessonNode(title: "Lunges", icon: .video, isLocked: false, reps: 12, restSec: 3),
        LessonNode(title: "Knee Extension", icon: .video, isLocked: false, reps: 12, restSec: 3)
    ]
    
    @State private var showingAddSheet = false
    @State private var addSelection = 0
    @State private var showingRehabOverview = false
    @State private var selectedNodeID: UUID? = nil
    @State private var showingEditor = false
    @State private var tempReps: Int = 12
    @State private var tempRest: Int = 3
    @State private var tempLocked: Bool = false
    
    // Drag state
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var pressedIndex: Int? = nil // Index of bubble that is "pressed"/enlarged by tap
    
    private let exerciseTypes = ["Knee Extension (Advanced)", "Wall Sits", "Lunges"]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            content
            
            // Confirm Journey button fixed at bottom
            VStack {
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
        isLoading = true
        errorMessage = nil
        
        do {
            // TODO: Use actual patient_profile_id from route
            // For now, get first patient as placeholder
            let patients = try await PTService.listMyPatients()
            guard let firstPatient = patients.first else {
                errorMessage = "No patient selected"
                isLoading = false
                return
            }
            
            try await RehabService.saveACLPlan(patientProfileId: firstPatient.patient_profile_id)
            
            // Navigate back to PatientDetailView
            router.go(.ptPatientDetail)
        } catch {
            errorMessage = error.localizedDescription
            print("PTJourneyMapView.confirmJourney error: \(error)")
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
                        showingAddSheet = true
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addLessonSheet
        }
        .overlay {
            if showingEditor {
                editorPopover
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
        .onAppear {
            layoutNodesZigZag()
        }
        .onChange(of: nodes.count) {
            layoutNodesZigZag()
        }
        .padding(.bottom, 100) // Extra padding for Confirm Journey button
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
    
    // MARK: - Add Lesson Sheet
    private var addLessonSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Add a Lesson")
                    .font(.rrHeadline)
                    .padding(.top)
                
                Picker("Exercise Type", selection: $addSelection) {
                    ForEach(0..<exerciseTypes.count, id: \.self) { index in
                        Text(exerciseTypes[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                
                Spacer()
                
                PrimaryButton(title: "Add Lesson") {
                    let newTitle = exerciseTypes[addSelection]
                    addNode(with: newTitle)
                    showingAddSheet = false
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                }
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
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedNodeTitle)
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                    
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
                    
                    Toggle(isOn: $tempLocked) {
                        Text("Lock Lesson?")
                            .font(.rrBody)
                    }
                    
                    PrimaryButton(title: "Set Parameters") {
                        commitEdit()
                    }
                }
                .padding(20)
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                )
            }
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
        }
        withAnimation(.spring()) {
            showingEditor = false
            selectedNodeID = nil
            pressedIndex = nil
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
    
    private func addNode(with title: String) {
        let newNode = LessonNode(title: title, icon: .video, isLocked: false, reps: 12, restSec: 3)
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

