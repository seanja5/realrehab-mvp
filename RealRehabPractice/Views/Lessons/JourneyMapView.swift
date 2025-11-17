import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject var router: Router
    @StateObject private var vm = JourneyMapViewModel()
    
    @State private var showCallout = false
    @State private var showSchedulePopover = false
    @State private var selectedNodeIndex: Int?
    @State private var showLockedPopup = false
    
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
    
    // Computed property for dynamic height
    private var maxHeight: CGFloat {
        CGFloat(max(vm.nodes.count * 120 + 40, 400))
    }
    
    // Get selected node title for popup
    private var selectedNodeTitle: String {
        guard let index = selectedNodeIndex, index < vm.nodes.count else {
            return "Lesson"
        }
        return vm.nodes[index].title.isEmpty ? "Lesson" : vm.nodes[index].title
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
                                    
                                    for (index, node) in vm.nodes.enumerated() {
                                        if index > 0 {
                                            currentX = (index % 2 == 0) ? width * 0.3 : width * 0.7
                                        }
                                        currentY = node.yOffset + 40
                                        path.addLine(to: CGPoint(x: currentX, y: currentY))
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
                            }
                            .frame(height: maxHeight)
                        }
                        .frame(height: maxHeight)
                        .padding(.horizontal, 16)
                        
                        Spacer()
                            .frame(height: 60)
                    }
                }
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
        .navigationTitle("Journey Map")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .overlay {
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
                                
                                PrimaryButton(title: "Go!") {
                                    router.go(.lesson)
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
            
            // Show lock icon for locked lessons, video icon for unlocked
            Image(systemName: node.isLocked ? "lock.fill" : "video.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
        }
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

