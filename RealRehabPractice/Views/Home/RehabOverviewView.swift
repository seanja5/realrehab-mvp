import SwiftUI

struct RehabOverviewView: View {
    @EnvironmentObject var router: Router

    // MARK: - State
    @State private var headerImageExists: Bool = (UIImage(named: "header-placeholder") != nil)

    @State private var startDate: Date = Date()
    @State private var startDateChosen: Bool = false
    @State private var showDatePicker: Bool = false

    @State private var selectedDays: Set<Weekday> = []
    @State private var times: [Weekday: Date] = [:]
    @State private var timePickerDay: Weekday? = nil
    @State private var showTimePicker: Bool = false

    @State private var allowReminders: Bool = false
    @State private var allowCamera: Bool = false

    private var canConfirm: Bool {
        startDateChosen && !selectedDays.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header media
                if headerImageExists {
                    Image("header-placeholder")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .overlay(
                            TrianglePlay()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .shadow(radius: 4),
                            alignment: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                            .frame(height: 180)
                        TrianglePlay()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(radius: 4)
                    }
                }

                // Title section
                Text("Knee Injury - ACL Rehab")
                    .font(.rrHeadline)

                Text("""
This rehabilitation journey will take you through a series of lessons and benchmarks for improvement, structured through 4 phases of recovery.
""")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                // Start date
                Text("When would you like to begin your rehab plan?")
                    .font(.rrTitle)
                FieldCard {
                    Button {
                        showDatePicker = true
                    } label: {
                        HStack {
                            Text(startDateChosen ? startDate.formatted(date: .abbreviated, time: .omitted)
                                                 : "Select start date")
                                .font(.rrBody)
                                .foregroundStyle(startDateChosen ? .primary : .secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }

                // Days & Times
                Text("Which days and times work best for your exercises?")
                    .font(.rrTitle)
                Text("Recommended: everyday")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        HStack(spacing: 12) {
                            DayChip(
                                selected: selectedDays.contains(day),
                                title: day.shortLabel
                            ) {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }

                            Spacer()

                            Button {
                                // Only allow time picking if day is selected
                                if selectedDays.contains(day) {
                                    timePickerDay = day
                                    showTimePicker = true
                                }
                            } label: {
                                HStack {
                                    let label: String = {
                                        if let t = times[day] {
                                            return t.formatted(date: .omitted, time: .shortened)
                                        } else {
                                            return "Select times"
                                        }
                                    }()
                                    Text(label)
                                        .font(.rrBody)
                                        .foregroundStyle(selectedDays.contains(day) ? .primary : .secondary)
                                    Image(systemName: "chevron.down")
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(!selectedDays.contains(day))
                        }
                    }
                }
                .padding(.top, 4)

                // Summary
                SummaryCard(
                    startDate: startDateChosen ? startDate : nil,
                    selected: selectedDays.sorted(by: { $0.order < $1.order }),
                    times: times
                )

                // Toggles
                Toggle("Allow Reminders", isOn: $allowReminders)
                    .font(.rrBody)
                    .padding(.top, 4)
                Toggle("Allow Camera", isOn: $allowCamera)
                    .font(.rrBody)

                // Bottom padding so the button isn't cramped
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom) {
            // Primary button at very bottom of page (not floating above content)
            VStack {
                PrimaryButton(title: "Confirm Journey!", isDisabled: !canConfirm) {
                    // Navigate forward or call your flow
                    // Example: router.go(.journeyMap)
                    router.go(.journeyMap)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial)
        }
        .navigationTitle("ACL Rehab")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .rrPageBackground()

        // MARK: - Sheets
        .sheet(isPresented: $showDatePicker) {
            VStack {
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                PrimaryButton(title: "Set Start Date") {
                    startDateChosen = true
                    showDatePicker = false
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTimePicker) {
            VStack {
                if let day = timePickerDay {
                    Text("Select time for \(day.name)")
                        .font(.rrTitle)
                        .padding(.top, 12)
                }

                let binding = Binding<Date>(
                    get: {
                        if let d = timePickerDay, let existing = times[d] {
                            return existing
                        }
                        return Date()
                    },
                    set: { newVal in
                        if let d = timePickerDay {
                            times[d] = newVal
                        }
                    }
                )

                DatePicker(
                    "Time",
                    selection: binding,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.vertical, 8)

                PrimaryButton(title: "Done") {
                    showTimePicker = false
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Helpers

private struct FieldCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .frame(minHeight: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .overlay(content, alignment: .leading)
    }
}

private struct SummaryCard: View {
    var startDate: Date?
    var selected: [Weekday]
    var times: [Weekday: Date]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule Summary:")
                .font(.rrTitle)

            HStack(alignment: .top) {
                Text("Start:")
                    .font(.rrCaption).foregroundStyle(.secondary)
                Spacer()
                Text(startDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                    .font(.rrBody)
            }

            HStack(alignment: .top) {
                Text("Days:")
                    .font(.rrCaption).foregroundStyle(.secondary)
                Spacer()
                Text(selected.isEmpty ? "—" : selected.map{ $0.shortLabel }.joined(separator: " / "))
                    .font(.rrBody)
            }

            HStack(alignment: .top) {
                Text("Times:")
                    .font(.rrCaption).foregroundStyle(.secondary)
                Spacer()
                if selected.isEmpty {
                    Text("—").font(.rrBody)
                } else {
                    Text(selected.compactMap { d in
                        if let t = times[d] {
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
        .padding(.vertical, 4)
    }
}

private struct DayChip: View {
    var selected: Bool
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.35), lineWidth: selected ? 0 : 1)
                    .background(
                        Circle()
                            .fill(selected ? Color.brandDarkBlue : Color.clear)
                    )
                    .frame(width: 34, height: 34)
                Text(title)
                    .font(.rrBody)
                    .foregroundStyle(selected ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

private struct TrianglePlay: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: 0.2*w, y: 0.1*h))
        p.addLine(to: CGPoint(x: 0.2*w, y: 0.9*h))
        p.addLine(to: CGPoint(x: 0.9*w, y: 0.5*h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Weekday

private enum Weekday: CaseIterable, Hashable {
    case sun, mon, tue, wed, thu, fri, sat

    static let allCasesOrdered: [Weekday] = [.sun, .mon, .tue, .wed, .thu, .fri, .sat]
    static var allCases: [Weekday] { allCasesOrdered }

    var order: Int {
        switch self {
        case .sun: return 0
        case .mon: return 1
        case .tue: return 2
        case .wed: return 3
        case .thu: return 4
        case .fri: return 5
        case .sat: return 6
        }
    }

    var name: String {
        switch self {
        case .sun: return "Sunday"
        case .mon: return "Monday"
        case .tue: return "Tuesday"
        case .wed: return "Wednesday"
        case .thu: return "Thursday"
        case .fri: return "Friday"
        case .sat: return "Saturday"
        }
    }

    var shortLabel: String {
        switch self {
        case .sun: return "S"
        case .mon: return "M"
        case .tue: return "T"
        case .wed: return "W"
        case .thu: return "T"
        case .fri: return "F"
        case .sat: return "S"
        }
    }
}
