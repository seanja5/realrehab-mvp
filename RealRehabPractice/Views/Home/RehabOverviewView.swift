import SwiftUI
import UIKit

struct RehabOverviewView: View {
    @EnvironmentObject var router: Router

    // MARK: - State
    @State private var selectedDays: Set<Weekday> = []
    @State private var times: [Weekday: Date] = [:]
    @State private var timePickerDay: Weekday? = nil
    @State private var showTimePicker: Bool = false

    @State private var allowReminders: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private var canConfirm: Bool {
        !selectedDays.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header media
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .overlay(
                        Image("aclrehab")
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    )

                // Title section
                Text("Knee Injury - ACL Rehab")
                    .font(.rrHeadline)

                Text("""
This rehabilitation journey will take you through a series of lessons and benchmarks for improvement, structured through 4 phases of recovery.
""")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

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
                    selected: selectedDays.sorted(by: { $0.order < $1.order }),
                    times: times
                )

                // Toggle
                Toggle("Allow Reminders", isOn: $allowReminders)
                    .font(.rrBody)
                    .padding(.top, 4)
                    .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))

                // Bottom padding so the button isn't cramped
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if let err = saveError {
                    Text(err)
                        .font(.rrCaption)
                        .foregroundStyle(.red)
                }
                PrimaryButton(title: isSaving ? "Saving…" : "Confirm Schedule!", isDisabled: !canConfirm || isSaving) {
                    confirmTapped()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial)
        }
        .task { await loadExistingSchedule() }
        .navigationTitle("ACL Rehab")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
        .rrPageBackground()

        // MARK: - Sheets
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

                TimePicker15(selection: binding)

                PrimaryButton(title: "Done") {
                    showTimePicker = false
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .presentationDetents([.medium])
        }
        .bluetoothPopupOverlay()
    }

    // MARK: - Actions

    private func confirmTapped() {
        saveError = nil
        isSaving = true

        let slots = ScheduleService.slotsFrom(selectedDays: selectedDays, times: times)

        Task {
            do {
                guard let profile = try await AuthService.myProfile() else {
                    throw NSError(domain: "RehabOverview", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
                }
                let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
                try await ScheduleService.saveSchedule(patientProfileId: patientProfileId, slots: slots)
                await MainActor.run {
                    isSaving = false
                    router.reset(to: .ptDetail)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func loadExistingSchedule() async {
        do {
            guard let profile = try await AuthService.myProfile() else {
                await MainActor.run { loadFromUserDefaults() }
                return
            }
            let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            let slots = try await ScheduleService.getSchedule(patientProfileId: patientProfileId)
            await MainActor.run {
                if slots.isEmpty {
                    loadFromUserDefaults()
                } else {
                    applySlotsToState(slots: slots)
                }
            }
        } catch {
            await MainActor.run { loadFromUserDefaults() }
        }
    }

    private func loadFromUserDefaults() {
        if let orders = UserDefaults.standard.array(forKey: "scheduleSelectedDays") as? [Int] {
            selectedDays = Set(orders.compactMap { Weekday(rawValue: $0) })
        }
        if let data = UserDefaults.standard.data(forKey: "scheduleTimes"),
           let dict = try? JSONDecoder().decode([Int: TimeInterval].self, from: data) {
            var newTimes: [Weekday: Date] = [:]
            for (order, interval) in dict {
                if let day = Weekday(rawValue: order) {
                    newTimes[day] = Date(timeIntervalSince1970: interval)
                }
            }
            times = newTimes
        }
    }

    private func applySlotsToState(slots: [ScheduleService.ScheduleSlot]) {
        var days = Set<Weekday>()
        var newTimes: [Weekday: Date] = [:]
        let cal = Calendar.current
        let ref = cal.startOfDay(for: Date())
        for slot in slots {
            guard let day = Weekday(rawValue: slot.day_of_week) else { continue }
            let parts = slot.slot_time.split(separator: ":")
            guard parts.count >= 2,
                  let h = Int(parts[0]),
                  let m = Int(parts[1]) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: ref)
            comps.hour = h
            comps.minute = m
            comps.second = 0
            if let d = cal.date(from: comps) {
                days.insert(day)
                newTimes[day] = d
            }
        }
        selectedDays = days
        times = newTimes
    }
}

// MARK: - Helpers

/// Time picker with 15-minute intervals (12:00, 12:15, 12:30, 12:45)
private struct TimePicker15: UIViewRepresentable {
    @Binding var selection: Date

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.minuteInterval = 15
        picker.preferredDatePickerStyle = .wheels
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.date = selection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    class Coordinator: NSObject {
        var selection: Binding<Date>
        init(selection: Binding<Date>) { self.selection = selection }

        @objc func changed(_ picker: UIDatePicker) {
            selection.wrappedValue = picker.date
        }
    }
}

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
    var selected: [Weekday]
    var times: [Weekday: Date]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule Summary:")
                .font(.rrTitle)

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

