import SwiftUI

/// Calendar-style schedule visualizer: days (S M T W T F S) across top, times on left,
/// dark brand blue rounded rectangles for 15-minute blocks. Each selected time fills 2 blocks (30 min).
/// No dates. Time range is dynamic based on slots.
struct ScheduleVisualizerView: View {
    /// Schedule slots from ScheduleService (day_of_week 0-6, slot_time "HH:mm:ss")
    /// Each slot is 30 min; it fills 2 consecutive 15-min blocks.
    let slots: [ScheduleService.ScheduleSlot]

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let defaultStartHour = 8
    private let defaultEndHour = 16
    private let slotCornerRadius: CGFloat = 4
    private let cellHeight: CGFloat = 8
    private let cellSpacing: CGFloat = 2
    private let blockMinutes = [0, 15, 30, 45]

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
            guard let (h, m) = parseTime(slot.slot_time) else { continue }
            minH = min(minH, h)
            let endH = m == 45 ? h + 1 : h
            maxH = max(maxH, endH)
        }
        if minH > maxH { return (defaultStartHour, defaultEndHour) }
        let start = max(0, minH - 1)
        let end = min(24, maxH + 2)
        return (start, end)
    }

    /// Check if 15-min block (day, hour, minute) is filled by any 30-min slot.
    /// A slot at (sh, sm) fills blocks (sh, sm) and (sh, sm+15) or (sh+1, 0) when sm==45.
    private func isFilled(day: Int, hour: Int, minute: Int) -> Bool {
        slots.contains { slot in
            guard slot.day_of_week == day,
                  let (sh, sm) = parseTime(slot.slot_time) else { return false }
            let block1 = (sh, sm)
            let block2 = sm == 45 ? (sh + 1, 0) : (sh, sm + 15)
            return (hour == block1.0 && minute == block1.1) || (hour == block2.0 && minute == block2.1)
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
                        Text(dayLabels[col])
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
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
                    .frame(height: CGFloat(blockMinutes.count) * cellHeight + CGFloat(blockMinutes.count - 1) * cellSpacing)
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
