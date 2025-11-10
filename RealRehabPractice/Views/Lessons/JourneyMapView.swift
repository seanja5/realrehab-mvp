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
        scheduleSelectedDays.compactMap { order in
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)
                    
                    GeometryReader { geometry in
                        ZStack {
                            Path { path in
                                let width = geometry.size.width
                                let startX = width * 0.3
                                var currentX = startX
                                var currentY: CGFloat = 40
                                
                                path.move(to: CGPoint(x: currentX, y: currentY))
                                
                                for (index, node) in nodes.enumerated() {
                                    if index > 0 {
                                        currentX = (index % 2 == 0) ? width * 0.3 : width * 0.7
                                    }
                                    currentY = node.yOffset + 40
                                    path.addLine(to: CGPoint(x: currentX, y: currentY))
                                }
                            }
                            .stroke(Color.brandLightBlue.opacity(0.4), lineWidth: 2)
                            
                            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                                let nodeX = (index % 2 == 0) ? geometry.size.width * 0.3 : geometry.size.width * 0.7
                                
                                NodeView(node: node)
                                    .position(x: nodeX, y: node.yOffset + 40)
                                    .onTapGesture {
                                        if !node.isLocked {
                                            showCallout = true
                                        }
                                    }
                            }
                        }
                        .frame(height: 1240)
                    }
                    .frame(height: 1240)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
            .rrPageBackground()
            .safeAreaInset(edge: .top) {
                headerCard
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .overlay(alignment: .topTrailing) {
                        if showSchedulePopover {
                            VStack {
                                Spacer()
                                    .frame(height: 80)
                                
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackButton()
                }
            }
            .overlay {
                if showCallout {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showCallout = false }
                        .overlay(alignment: .top) {
                            VStack(spacing: 16) {
                                Text("Lesson 1 – Knee Extension")
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                
                                PrimaryButton(title: "Go!") {
                                    router.go(.lesson)
                                    showCallout = false
                                }
                                .padding(.horizontal, 24)
                                
                                SecondaryButton(title: "Close") {
                                    showCallout = false
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
            
            PatientTabBar(
                selected: .journey,
                onSelect: { tab in
                    switch tab {
                    case .dashboard:
                        router.go(.ptDetail)
                    case .journey:
                        break
                    case .settings:
                        router.go(.patientSettings)
                    }
                },
                onAddTapped: {
                    router.go(.pairDevice)
                }
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 0) {
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
    
    // Helper views below remain unchanged ...
    
    private func NodeView(node: JourneyNode) -> some View {
        ZStack {
            Circle()
                .fill(node.isLocked ? Color.gray.opacity(0.3) : Color.brandDarkBlue)
                .frame(width: 60, height: 60)
                .shadow(color: node.isLocked ? Color.gray.opacity(0.2) : Color.brandDarkBlue.opacity(0.4), radius: 12, x: 0, y: 2)
            
            Image(systemName: node.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
        }
    }
    
    private struct JourneyNode: Identifiable {
        let id = UUID()
        let icon: String
        let isLocked: Bool
        let title: String
        let yOffset: CGFloat
    }
}

struct ScheduleSummaryPopover: View {
    let startDate: Date?
    let selectedDays: [Weekday]
    let times: [Int: Date]
    let onDismiss: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedule Summary")
                    .font(.rrTitle)
                Spacer()
                Button("Close") { onDismiss() }
                    .font(.rrCaption)
            }
            
            if let startDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: startDate))
                        .font(.rrBody)
                }
            }
            
            if !selectedDays.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Days")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(selectedDays.map { $0.name }.joined(separator: ", "))
                        .font(.rrBody)
                }
            }
            
            if !times.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Times")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    ForEach(times.keys.sorted(), id: \.self) { key in
                        if let date = times[key] {
                            Text("Day \(key + 1): \(timeFormatter.string(from: date))")
                                .font(.rrBody)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
    }
}

