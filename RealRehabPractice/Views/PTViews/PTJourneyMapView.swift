import SwiftUI

struct PTJourneyMapView: View {
    @EnvironmentObject var router: Router
    
    // MARK: - State
    @State private var nodes: [LessonNode] = [
        LessonNode(title: "Knee Extension", icon: .person, isLocked: false, reps: 12, restSec: 30),
        LessonNode(title: "Wall Sits", icon: .video, isLocked: false, reps: 12, restSec: 30),
        LessonNode(title: "Lunges", icon: .video, isLocked: false, reps: 12, restSec: 30),
        LessonNode(title: "Knee Extension", icon: .video, isLocked: false, reps: 12, restSec: 30),
        LessonNode(title: "Wall Sits", icon: .video, isLocked: false, reps: 12, restSec: 30),
        LessonNode(title: "Lunges", icon: .video, isLocked: false, reps: 12, restSec: 30),
        LessonNode(title: "Knee Extension", icon: .video, isLocked: false, reps: 12, restSec: 30)
    ]
    
    @State private var showingAddSheet = false
    @State private var addSelection = 0
    @State private var showingRehabOverview = false
    @State private var selectedNodeIndex: Int?
    @State private var showingEditor = false
    
    // Drag state
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    private let exerciseTypes = ["Knee Extension (Advanced)", "Wall Sits", "Lunges"]
    
    var body: some View {
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
                                scale: draggingIndex == index ? 1.2 : 1.0
                            )
                            .position(displayPosition)
                            .gesture(
                                LongPressGesture(minimumDuration: 0.3)
                                    .sequenced(before: DragGesture(minimumDistance: 0))
                                    .onChanged { value in
                                        switch value {
                                        case .second(true, let drag):
                                            if let dragValue = drag {
                                                if draggingIndex == nil {
                                                    draggingIndex = index
                                                    isDragging = true
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        // Trigger scale animation
                                                    }
                                                }
                                                dragOffset = dragValue.translation
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    .onEnded { value in
                                        switch value {
                                        case .second(true, let drag):
                                            if let dragValue = drag {
                                                handleDragEnd(from: index, translation: dragValue.translation, geometry: geometry)
                                            }
                                        default:
                                            break
                                        }
                                    }
                            )
                            .onTapGesture {
                                if draggingIndex == nil {
                                    selectedNodeIndex = index
                                    showingEditor = true
                                }
                            }
                        }
                    }
                    .frame(height: maxHeight)
                }
                .frame(height: maxHeight)
                .padding(.horizontal, 16)
                
                // Bottom padding
                Spacer()
                    .frame(height: 100)
            }
        }
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
            if showingEditor, let index = selectedNodeIndex {
                editorPopover(for: nodes[index], index: index)
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
    private func editorPopover(for node: LessonNode, index: Int) -> some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                showingEditor = false
                selectedNodeIndex = nil
            }
            .overlay {
                VStack(spacing: 20) {
                    Text(node.title)
                        .font(.rrTitle)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set number of repetitions")
                            .font(.rrBody)
                        
                        HStack {
                            Menu {
                                Button("8") { nodes[index].reps = 8 }
                                Button("10") { nodes[index].reps = 10 }
                                Button("12") { nodes[index].reps = 12 }
                                Button("15") { nodes[index].reps = 15 }
                                Button("20") { nodes[index].reps = 20 }
                            } label: {
                                HStack {
                                    Text("\(nodes[index].reps)")
                                        .font(.rrBody)
                                    Image(systemName: "chevron.down")
                                        .font(.rrCaption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            TextField("", value: Binding(
                                get: { nodes[index].reps },
                                set: { nodes[index].reps = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time in between repetitions (sec)")
                            .font(.rrBody)
                        
                        HStack {
                            Menu {
                                Button("2") { nodes[index].restSec = 2 }
                                Button("3") { nodes[index].restSec = 3 }
                                Button("5") { nodes[index].restSec = 5 }
                                Button("10") { nodes[index].restSec = 10 }
                            } label: {
                                HStack {
                                    Text("\(nodes[index].restSec)")
                                        .font(.rrBody)
                                    Image(systemName: "chevron.down")
                                        .font(.rrCaption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            TextField("", value: Binding(
                                get: { nodes[index].restSec },
                                set: { nodes[index].restSec = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        }
                    }
                    
                    Toggle("Lock Lesson?", isOn: Binding(
                        get: { nodes[index].isLocked },
                        set: { nodes[index].isLocked = $0 }
                    ))
                    
                    PrimaryButton(title: "Set Parameters") {
                        showingEditor = false
                        selectedNodeIndex = nil
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 40)
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
        let nodeX = (index % 2 == 0) ? geometry.size.width * 0.3 : geometry.size.width * 0.7
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

