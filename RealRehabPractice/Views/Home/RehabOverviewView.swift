import SwiftUI
import UIKit

struct RehabOverviewView: View {
    @EnvironmentObject var router: Router

    // MARK: - State
    @State private var selectedDays: Set<Weekday> = []
    @State private var times: [Weekday: [Date]] = [:]
    @State private var timePickerDay: Weekday? = nil
    @State private var timePickerIndex: Int = 0
    @State private var showTimePicker: Bool = false
    @State private var pendingTimePickerValue: Date = Date()

    @State private var allowReminders: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var duplicateTimeMessage: String?

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
                Text("Choose up to 2 start times per day.")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)

                // Column headers: First Time | Second Time
                HStack(spacing: 8) {
                    Color.clear.frame(width: 34)
                    Text("First Time")
                        .font(.rrCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 22)
                    Text("Second Time")
                        .font(.rrCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 22)
                }
                .padding(.top, 12)
                .padding(.bottom, 4)

                VStack(spacing: 8) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        DayScheduleRow(
                            day: day,
                            times: bindingForTimes(day: day),
                            isSelected: selectedDays.contains(day),
                            onToggleDay: { toggleDay(day) },
                            onTapDropdown: { index in openTimePicker(day: day, index: index) },
                            onClearTime: { index in clearTime(day: day, index: index) }
                        )
                    }
                }

                if let msg = duplicateTimeMessage {
                    Text(msg)
                        .font(.rrCaption)
                        .foregroundStyle(.orange)
                }

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

        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
        .onChange(of: showTimePicker) { _, isShowing in
            if isShowing, let day = timePickerDay {
                let arr = times[day] ?? []
                pendingTimePickerValue = arr.indices.contains(timePickerIndex) ? arr[timePickerIndex] : Date()
            }
        }
        .bluetoothPopupOverlay()
    }

    private var timePickerSheet: some View {
        VStack {
            if let day = timePickerDay {
                Text("Select time for \(day.name)")
                    .font(.rrTitle)
                    .padding(.top, 12)
            }

            TimePicker15(selection: $pendingTimePickerValue)

            PrimaryButton(title: "Done") {
                if let day = timePickerDay {
                    setTime(day: day, index: timePickerIndex, value: pendingTimePickerValue)
                }
                duplicateTimeMessage = nil
                showTimePicker = false
            }
            .padding(.top, 8)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func bindingForTimes(day: Weekday) -> Binding<[Date]> {
        Binding(
            get: { times[day] ?? [] },
            set: { times[day] = $0 }
        )
    }

    private func toggleDay(_ day: Weekday) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
            times[day] = nil
        } else {
            selectedDays.insert(day)
            // Do NOT add times - boxes stay "Select" until user picks via dropdown
        }
        duplicateTimeMessage = nil
    }

    private func openTimePicker(day: Weekday, index: Int) {
        if !selectedDays.contains(day) {
            selectedDays.insert(day)
        }
        // Second slot: require first slot to have a value
        if index == 1 {
            let arr = times[day] ?? []
            guard arr.indices.contains(0) else { return }
        }
        timePickerDay = day
        timePickerIndex = index
        showTimePicker = true
        duplicateTimeMessage = nil
    }

    private func clearTime(day: Weekday, index: Int) {
        var arr = times[day] ?? []
        guard arr.indices.contains(index) else { return }
        arr.remove(at: index)
        times[day] = arr.isEmpty ? nil : arr
        if arr.isEmpty {
            selectedDays.remove(day)
        }
        duplicateTimeMessage = nil
    }

    private func setTime(day: Weekday, index: Int, value: Date) {
        var arr = times[day] ?? []
        while arr.count <= index { arr.append(Date()) }
        arr[index] = value
        times[day] = arr

        // Check for duplicate within same day
        let rounded = ScheduleService.timeString(from: value)
        let others = arr.enumerated().filter { $0.offset != index }.map { ScheduleService.timeString(from: $0.element) }
        if others.contains(rounded) {
            duplicateTimeMessage = "Duplicate time on \(day.name). Please choose a different time."
        } else {
            duplicateTimeMessage = nil
        }
    }

    // MARK: - Actions

    private func confirmTapped() {
        saveError = nil
        duplicateTimeMessage = nil

        // Validate: no duplicate times per day
        for day in selectedDays {
            guard let arr = times[day], arr.count > 1 else { continue }
            let strings = arr.map { ScheduleService.timeString(from: $0) }
            if Set(strings).count != strings.count {
                duplicateTimeMessage = "Please remove duplicate times for \(day.name)."
                return
            }
        }

        isSaving = true
        let slots = ScheduleService.slotsFrom(selectedDays: selectedDays, times: times)

        // Persist to UserDefaults (fallback / offline)
        UserDefaults.standard.set(Array(selectedDays.map { $0.rawValue }), forKey: "scheduleSelectedDays")
        var timesDict: [Int: [TimeInterval]] = [:]
        for (day, arr) in times {
            timesDict[day.rawValue] = arr.map { $0.timeIntervalSince1970 }
        }
        if let encoded = try? JSONEncoder().encode(timesDict) {
            UserDefaults.standard.set(encoded, forKey: "scheduleTimes")
        }

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
                await MainActor.run { resetToBlank() }
                return
            }
            let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            let slots = try await ScheduleService.getSchedule(patientProfileId: patientProfileId)
            await MainActor.run {
                if slots.isEmpty {
                    // Creating schedule: start blank. Do NOT load from UserDefaults (it's not per-account).
                    resetToBlank()
                } else {
                    // Editing schedule: show existing slots
                    applySlotsToState(slots: slots)
                }
            }
        } catch {
            await MainActor.run { resetToBlank() }
        }
    }

    private func resetToBlank() {
        selectedDays = []
        times = [:]
    }

    private func loadFromUserDefaults() {
        if let orders = UserDefaults.standard.array(forKey: "scheduleSelectedDays") as? [Int] {
            selectedDays = Set(orders.compactMap { Weekday(rawValue: $0) })
        }
        if let data = UserDefaults.standard.data(forKey: "scheduleTimes"),
           let dict = try? JSONDecoder().decode([Int: [TimeInterval]].self, from: data) {
            var newTimes: [Weekday: [Date]] = [:]
            for (order, intervals) in dict {
                if let day = Weekday(rawValue: order) {
                    newTimes[day] = intervals.map { Date(timeIntervalSince1970: $0) }
                }
            }
            times = newTimes
        }
        // Migrate old format [Int: TimeInterval] (single time per day)
        if times.isEmpty, let data = UserDefaults.standard.data(forKey: "scheduleTimes"),
           let dict = try? JSONDecoder().decode([Int: TimeInterval].self, from: data) {
            var newTimes: [Weekday: [Date]] = [:]
            for (order, interval) in dict {
                if let day = Weekday(rawValue: order) {
                    newTimes[day] = [Date(timeIntervalSince1970: interval)]
                }
            }
            times = newTimes
        }
    }

    private func applySlotsToState(slots: [ScheduleService.ScheduleSlot]) {
        var days = Set<Weekday>()
        var newTimes: [Weekday: [Date]] = [:]
        let cal = Calendar.current
        let ref = cal.startOfDay(for: Date())

        for day in Weekday.allCases {
            let daySlots = slots.filter { $0.day_of_week == day.rawValue }
            guard !daySlots.isEmpty else { continue }
            var dayDates: [Date] = []
            for slot in daySlots {
                let parts = slot.slot_time.split(separator: ":")
                guard parts.count >= 2,
                      let h = Int(parts[0]),
                      let m = Int(parts[1]) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: ref)
                comps.hour = h
                comps.minute = m
                comps.second = 0
                if let d = cal.date(from: comps) {
                    dayDates.append(d)
                }
            }
            if !dayDates.isEmpty {
                days.insert(day)
                newTimes[day] = dayDates.sorted { $0 < $1 }
            }
        }
        selectedDays = days
        times = newTimes
    }
}

// MARK: - DayScheduleRow

private struct DayScheduleRow: View {
    let day: Weekday
    @Binding var times: [Date]
    let isSelected: Bool
    let onToggleDay: () -> Void
    let onTapDropdown: (Int) -> Void
    let onClearTime: (Int) -> Void

    private var hasAnyTime: Bool { !times.isEmpty }

    var body: some View {
        HStack(spacing: 8) {
            DayChip(
                selected: isSelected || hasAnyTime,
                title: day.shortLabel
            ) {
                onToggleDay()
            }

            // First time slot
            HStack(spacing: 4) {
                TimeDropdownButton(
                    label: times.indices.contains(0) ? times[0].formatted(date: .omitted, time: .shortened) : "Select",
                    isActive: isSelected || hasAnyTime
                ) {
                    onTapDropdown(0)
                }
                .frame(width: 100)

                Button {
                    onClearTime(0)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(times.indices.contains(0) ? .secondary : Color.secondary.opacity(0.3))
                }
                .disabled(!times.indices.contains(0))
            }
            .frame(maxWidth: .infinity)

            // Second time slot
            HStack(spacing: 4) {
                TimeDropdownButton(
                    label: times.indices.contains(1) ? times[1].formatted(date: .omitted, time: .shortened) : "Select",
                    isActive: isSelected || hasAnyTime,
                    isDisabled: !times.indices.contains(0)
                ) {
                    onTapDropdown(1)
                }
                .frame(width: 100)

                Button {
                    onClearTime(1)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(times.indices.contains(1) ? .secondary : Color.secondary.opacity(0.3))
                }
                .disabled(!times.indices.contains(1))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
        )
    }
}

private struct TimeDropdownButton: View {
    let label: String
    let isActive: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.rrBody)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(isActive && !isDisabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .buttonStyle(.plain)
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

private struct SummaryCard: View {
    var selected: [Weekday]
    var times: [Weekday: [Date]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule Summary:")
                .font(.rrTitle)

            HStack(alignment: .top) {
                Text("Days:")
                    .font(.rrCaption).foregroundStyle(.secondary)
                Spacer()
                Text(selected.isEmpty ? "—" : selected.map { $0.shortLabel }.joined(separator: " / "))
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
                        guard let t = times[d], !t.isEmpty else { return nil }
                        let timeStrs = t.map { $0.formatted(date: .omitted, time: .shortened) }
                        return "\(d.shortLabel) \(timeStrs.joined(separator: ", "))"
                    }.joined(separator: "; "))
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
