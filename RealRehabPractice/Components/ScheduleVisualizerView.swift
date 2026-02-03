import SwiftUI

/// Calendar-style schedule visualizer: days (S M T W T F S) across top, times on left,
/// dark brand blue rounded rectangles for 30-minute blocks. No dates.
/// Time range is dynamic: 8 AM–3 PM when empty, expands to fit selected times when slots exist.
struct ScheduleVisualizerView: View {
    /// Schedule slots from ScheduleService (day_of_week 0-6, slot_time "HH:mm:ss")
    let slots: [ScheduleService.ScheduleSlot]

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let defaultStartHour = 8
    private let defaultEndHour = 16  // 8 AM through 3:30 PM
    private let slotCornerRadius: CGFloat = 6
    private let cellHeight: CGFloat = 12
    private let cellSpacing: CGFloat = 4
    private let rowHeight: CGFloat = 28

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
        // Include 30-min slot after last hour; add 1 hour padding before/after
        let start = max(0, minH - 1)
        let end = min(24, maxH + 2)  // +2 to include :30 slot and padding
        return (start, end)
    }

    /// Check if slot (day, hour, minute) is filled
    private func isFilled(day: Int, hour: Int, minute: Int) -> Bool {
        slots.contains { slot in
            guard slot.day_of_week == day,
                  let (h, m) = parseTime(slot.slot_time) else { return false }
            return h == hour && m == minute
        }
    }

    var body: some View {
        let range = hourRange

        VStack(alignment: .leading, spacing: 8) {
            Text("My Schedule")
                .font(.rrTitle)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                // Header row: empty corner + day labels
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

                // Time rows: dynamic range
                ForEach(range.start..<range.end, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(timeLabel(hour))
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)

                        HStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { day in
                                VStack(spacing: cellSpacing) {
                                    cellView(filled: isFilled(day: day, hour: hour, minute: 0))
                                    cellView(filled: isFilled(day: day, hour: hour, minute: 30))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: rowHeight)
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
    }
}
