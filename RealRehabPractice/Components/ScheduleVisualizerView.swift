import SwiftUI

/// Calendar-style schedule visualizer: days (S M T W T F S) across top, times on left,
/// dark brand blue rounded rectangles for 30-minute blocks. Each selected time fills 1 block.
/// No dates. Time range is dynamic based on slots.
struct ScheduleVisualizerView: View {
    /// Schedule slots from ScheduleService (day_of_week 0-6, slot_time "HH:mm:ss")
    /// Each slot is 30 min; it fills 1 block (e.g. 12:00 fills 12:00–12:30 block).
    let slots: [ScheduleService.ScheduleSlot]

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let defaultStartHour = 8
    private let defaultEndHour = 16
    private let slotCornerRadius: CGFloat = 4
    private let cellHeight: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let blockMinutes = [0, 30]
    /// Extra spacing between hour rows so blocks don't touch across hours
    private let rowSpacing: CGFloat = 6

    /// Parse "HH:mm" or "HH:mm:ss" to (hour, minute) or nil
    private func parseTime(_ s: String) -> (hour: Int, minute: Int)? {
        let parts = s.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              h >= 0, h <= 23, m >= 0, m < 60 else { return nil }
        return (h, m)
    }

    /// Compute dynamic hour range from slots; use default when empty
    private var hourRange: (start: Int, end: Int) {
        if slots.isEmpty {
            return (defaultStartHour, defaultEndHour)
        }
        var minH = 23
        var maxH = 0
        for slot in slots {
            guard let (h, _) = parseTime(slot.slot_time) else { continue }
            minH = min(minH, h)
            maxH = max(maxH, h)
        }
        if minH > maxH { return (defaultStartHour, defaultEndHour) }
        let start = max(0, minH - 1)
        let end = min(24, maxH + 2)
        return (start, end)
    }

    /// Days that have at least one slot (selected days)
    private var selectedDays: Set<Int> {
        Set(slots.map { $0.day_of_week })
    }

    /// Check if 30-min block (day, hour, minute) is filled. Each slot fills exactly 1 block.
    /// Slot at (sh, sm): maps to block (sh, 0) if sm < 30, else (sh, 30).
    private func isFilled(day: Int, hour: Int, minute: Int) -> Bool {
        slots.contains { slot in
            guard slot.day_of_week == day,
                  let (sh, sm) = parseTime(slot.slot_time) else { return false }
            let blockMin = sm < 30 ? 0 : 30
            return hour == sh && minute == blockMin
        }
    }

    var body: some View {
        let range = hourRange

        VStack(alignment: .leading, spacing: 8) {
            Text("My Schedule")
                .font(.rrTitle)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
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
                .padding(.bottom, 4)

                ForEach(range.start..<range.end, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(timeLabel(hour))
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)

                        HStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { day in
                                VStack(spacing: cellSpacing) {
                                    ForEach(blockMinutes, id: \.self) { minute in
                                        cellView(filled: isFilled(day: day, hour: hour, minute: minute))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: CGFloat(blockMinutes.count) * cellHeight + CGFloat(blockMinutes.count - 1) * cellSpacing + rowSpacing)
                    .padding(.bottom, rowSpacing)
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

    private func timeLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 12: return "12 PM"
        case 1..<12: return "\(hour) AM"
        default: return "\(hour - 12) PM"
        }
    }

    @ViewBuilder
    private func cellView(filled: Bool) -> some View {
        RoundedRectangle(cornerRadius: slotCornerRadius)
            .fill(filled ? Color.brandDarkBlue : Color.gray.opacity(0.12))
            .frame(height: cellHeight)
            .frame(maxWidth: .infinity)
    }
}
