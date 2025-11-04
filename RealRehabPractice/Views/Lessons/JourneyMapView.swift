import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject var router: Router
    
    @State private var showCallout = false
    @State private var showSchedulePopover = false
    
    // Load schedule data from UserDefaults
    private var scheduleStartDate: Date? {
        guard UserDefaults.standard.bool(forKey: "scheduleStartDateChosen"),
              let date = UserDefaults.standard.object(forKey: "scheduleStartDate") as? Date else {
            return nil
        }
        return date
    }
    
    private var scheduleSelectedDays: [Int] {
        UserDefaults.standard.array(forKey: "scheduleSelectedDays") as? [Int] ?? []
    }
    
    private var scheduleTimes: [Int: Date] {
        guard let data = UserDefaults.standard.data(forKey: "scheduleTimes"),
              let dict = try? JSONDecoder().decode([Int: TimeInterval].self, from: data) else {
            return [:]
        }
        return dict.mapValues { Date(timeIntervalSince1970: $0) }
    }
    
    // Convert day orders to Weekday enum for display
    private var scheduleWeekdays: [Weekday] {
        return scheduleSelectedDays.compactMap { order in
            Weekday.allCases.first { $0.order == order }
        }
    }
    
    // Sample nodes - first is active, rest are locked
    private let nodes: [JourneyNode] = [
        JourneyNode(icon: "figure.stand", isLocked: false, title: "Lesson 1 – Knee Extension", yOffset: 0),
        JourneyNode(icon: "video.fill", isLocked: true, title: "", yOffset: 120),
        JourneyNode(icon: "video.fill", isLocked: true, title: "", yOffset: 240),
        JourneyNode(icon: "lock.fill", isLocked: true, title: "", yOffset: 360),
        JourneyNode(icon: "flag.fill", isLocked: true, title: "", yOffset: 480),
        JourneyNode(icon: "lock.fill", isLocked: true, title: "", yOffset: 600),
        JourneyNode(icon: "lock.fill", isLocked: true, title: "", yOffset: 720),
        JourneyNode(icon: "lock.fill", isLocked: true, title: "", yOffset: 840),
        JourneyNode(icon: "lock.fill", isLocked: true, title: "", yOffset: 960),
        JourneyNode(icon: "lock.fill", isLocked: true, title: "", yOffset: 1080)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top padding to push content below sticky header
                Spacer()
                    .frame(height: 40)
                
                // Journey path container
                GeometryReader { geometry in
                    ZStack {
                        // Draw the diagonal path
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
                        
                        // Draw nodes
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            let nodeX = (index % 2 == 0) ? geometry.size.width * 0.3 : geometry.size.width * 0.7
                            
                            NodeView(node: node)
                                .position(x: nodeX, y: node.yOffset + 40) // Offset all nodes down
                                .onTapGesture {
                                    if !node.isLocked {
                                        showCallout = true
                                    }
                                }
                        }
                    }
                    .frame(height: 1240) // Increased to accommodate the offset
                }
                .frame(height: 1240)
                .padding(.horizontal, 16)
                
                // Bottom padding
                Spacer()
                    .frame(height: 100)
            }
        }
        .safeAreaInset(edge: .top) {
            // Sticky header card
            headerCard
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .overlay(alignment: .topTrailing) {
                    // Schedule popover positioned below header
                    if showSchedulePopover {
                        VStack {
                            Spacer()
                                .frame(height: 80) // Height of header card
                            
                            HStack {
                                Spacer()
                                
                                ScheduleSummaryPopover(
                                    startDate: scheduleStartDate,
                                    selectedDays: scheduleWeekdays,
                                    times: scheduleTimes,
                                    onDismiss: {
                                        showSchedulePopover = false
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
        .overlay {
            // Callout overlay
            if showCallout {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showCallout = false
                    }
                    .overlay(alignment: .top) {
                        VStack(spacing: 16) {
                            Text("Lesson 1 – Knee Extension")
                                .font(.rrTitle)
                                .foregroundStyle(.primary)
                            
                            PrimaryButton(title: "Go!") {
                                showCallout = false
                                router.go(.lesson)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                        )
                        .padding(.horizontal, 40)
                        .offset(y: 200)
                    }
            }
            
            // Dismiss popover when tapping outside
            if showSchedulePopover {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        showSchedulePopover = false
                    }
            }
        }
    }
    
    // MARK: - Header Card
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
                // Icons stack
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
                    showSchedulePopover.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Journey Node Model
struct JourneyNode: Identifiable {
    let id = UUID()
    let icon: String
    let isLocked: Bool
    let title: String
    let yOffset: CGFloat
}

// MARK: - Node View
struct NodeView: View {
    let node: JourneyNode
    
    var body: some View {
        ZStack {
            Circle()
                .fill(nodeFillColor)
                .frame(width: 60, height: 60)
                .shadow(color: nodeShadowColor, radius: node.isLocked ? 4 : 12, x: 0, y: 2)
            
            Image(systemName: node.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(nodeIconColor)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(node.isLocked ? [] : .isButton)
    }
    
    private var nodeFillColor: Color {
        if node.isLocked {
            return Color.gray.opacity(0.25)
        } else if node.icon == "figure.stand" {
            return Color.brandDarkBlue
        } else {
            return Color.brandDarkBlue.opacity(0.7)
        }
    }
    
    private var nodeIconColor: Color {
        if node.isLocked {
            return Color.gray.opacity(0.6)
        } else {
            return .white
        }
    }
    
    private var nodeShadowColor: Color {
        if node.isLocked {
            return .black.opacity(0.1)
        } else {
            return Color.brandDarkBlue.opacity(0.4)
        }
    }
    
    private var accessibilityLabel: String {
        if node.isLocked {
            return "Locked node"
        } else if node.icon == "video.fill" {
            return "Video lesson node"
        } else if node.icon == "flag.fill" {
            return "Goal node"
        } else {
            return "Lesson node"
        }
    }
}

// MARK: - Schedule Summary Popover
struct ScheduleSummaryPopover: View {
    let startDate: Date?
    let selectedDays: [Weekday]
    let times: [Int: Date]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule Summary:")
                .font(.rrTitle)
            
            HStack(alignment: .top) {
                Text("Start:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(startDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                    .font(.rrBody)
            }
            
            HStack(alignment: .top) {
                Text("Days:")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                    Text(selectedDays.isEmpty ? "—" : selectedDays.map { $0.shortLabel }.joined(separator: " / "))
                    .font(.rrBody)
                }
                
                HStack(alignment: .top) {
                    Text("Times:")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if selectedDays.isEmpty {
                        Text("—").font(.rrBody)
                    } else {
                        Text(selectedDays.compactMap { d in
                            if let t = times[d.order] {
                                return "\(d.shortLabel) \(t.formatted(date: .omitted, time: .shortened))"
                            } else {
                                return nil
                            }
                        }.joined(separator: ", "))
                        .font(.rrBody)
                        .multilineTextAlignment(.trailing)
                    }
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

