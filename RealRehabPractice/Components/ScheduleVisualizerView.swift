import SwiftUI

/// Calendar-style schedule visualizer: days (S M T W T F S) across top, times on left.
/// One gray rounded column per day; blue blocks overlaid at exact start times (15-min granularity).
/// Each slot is 30 min. Supports times like 3:15, 3:45.
struct ScheduleVisualizerView: View {
    /// Schedule slots from ScheduleService (day_of_week 0-6, slot_time "HH:mm:ss")
    let slots: [ScheduleService.ScheduleSlot]

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let defaultStartHour = 8
    private let defaultEndHour = 16
    private let columnCornerRadius: CGFloat = 6
    private let blockCornerRadius: CGFloat = 4
    private let columnHeight: CGFloat = 200
    private let slotDurationMinutes = 30

    /// Parse "HH:mm" or "HH:mm:ss" to total minutes since midnight, or nil
    private func parseTimeToMinutes(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              h >= 0, h <= 23, m >= 0, m < 60 else { return nil }
        return h * 60 + m
    }

    /// Compute dynamic hour range from slots; use default when empty
    private var hourRange: (start: Int, end: Int) {
        if slots.isEmpty {
            return (defaultStartHour, defaultEndHour)
        }
        var minH = 23
        var maxH = 0
        for slot in slots {
            guard let mins = parseTimeToMinutes(slot.slot_time) else { continue }
            let h = mins / 60
            minH = min(minH, h)
            maxH = max(maxH, h)
        }
        if minH > maxH { return (defaultStartHour, defaultEndHour) }
        let start = max(0, minH - 1)
        let end = min(24, maxH + 2)
        return (start, end)
    }

    private var startMinutes: Int { hourRange.start * 60 }
    private var endMinutes: Int { hourRange.end * 60 }
    private var totalMinutes: Int { endMinutes - startMinutes }

    /// Days that have at least one slot (selected days)
    private var selectedDays: Set<Int> {
        Set(slots.map { $0.day_of_week })
    }

    /// Slots for a given day
    private func slots(for day: Int) -> [ScheduleService.ScheduleSlot] {
        slots.filter { $0.day_of_week == day }
    }

    /// Fraction (0...1) for top of a slot block; 0 = top of column
    private func topFraction(for slotMinutes: Int) -> CGFloat {
        let offset = slotMinutes - startMinutes
        guard totalMinutes > 0, offset >= 0 else { return 0 }
        return CGFloat(offset) / CGFloat(totalMinutes)
    }

    /// Fraction (0...1) of column height for a 30-min block
    private var heightFraction: CGFloat {
        guard totalMinutes > 0 else { return 0 }
        return CGFloat(slotDurationMinutes) / CGFloat(totalMinutes)
    }

    var body: some View {
        let range = hourRange

        VStack(alignment: .leading, spacing: 8) {
            Text("My Schedule")
                .font(.rrTitle)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                // Day headers
                HStack(spacing: 0) {
                    Color.clear.frame(width: 44, height: 24)
                    ForEach(0..<7, id: \.self) { col in
                        let isSelected = selectedDays.contains(col)
                        HStack {
                            Spacer()
                            Text(dayLabels[col])
                                .font(.rrCaption)
                                .foregroundStyle(isSelected ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? Color.brandDarkBlue : Color.clear)
                                )
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 8)

                // Time labels + day columns
                HStack(alignment: .top, spacing: 0) {
                    // Time labels on the left (shifted up so first label rests above top of gray columns)
                    let labelHeight = columnHeight / CGFloat(range.end - range.start)
                    VStack(spacing: 0) {
                        ForEach(range.start..<range.end, id: \.self) { hour in
                            Text(timeLabel(hour))
                                .font(.rrCaption)
                                .foregroundStyle(.secondary)
                                .frame(height: labelHeight)
                        }
                    }
                    .frame(width: 44, height: columnHeight)
                    .offset(y: -labelHeight * 0.5)

                    // Day columns: one gray rect per day, blue blocks overlaid
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            dayColumn(day: day)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
            )
        }
    }

    @ViewBuilder
    private func dayColumn(day: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = columnHeight

            ZStack(alignment: .top) {
                // One big gray rounded rectangle per day
                RoundedRectangle(cornerRadius: columnCornerRadius)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: w, height: h)

                // Blue blocks overlaid at exact start times
                ForEach(Array(slots(for: day).enumerated()), id: \.offset) { _, slot in
                    if let slotMins = parseTimeToMinutes(slot.slot_time) {
                        let topFrac = topFraction(for: slotMins)
                        let blockHeight = h * heightFraction
                        RoundedRectangle(cornerRadius: blockCornerRadius)
                            .fill(Color.brandDarkBlue)
                            .frame(width: max(0, w - 2), height: max(2, blockHeight))
                            .offset(y: topFrac * h)
                    }
                }
            }
        }
        .frame(height: columnHeight)
        .frame(maxWidth: .infinity)
    }

    private func timeLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 12: return "12 PM"
        case 1..<12: return "\(hour) AM"
        default: return "\(hour - 12) PM"
        }
    }
}
