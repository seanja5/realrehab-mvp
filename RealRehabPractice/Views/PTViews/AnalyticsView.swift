import SwiftUI

// MARK: - AnalyticsView

struct AnalyticsView: View {
    let lessonTitle: String
    let lessonId: UUID?
    let patientProfileId: UUID?
    
    @EnvironmentObject private var router: Router
    
    /// Hardcoded lesson duration (sec) for x-axis scaling.
    private static let hardcodedDuration: Double = 180
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpace.section * 2) {
                // Large title + gray bar
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(lessonTitle) Results")
                        .font(.rrHeadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Section 1: Dynamic Valgus (Leg Drift)
                analyticsSection(
                    title: "Dynamic Valgus (Leg Drift Graph)",
                    visual: {
                        DriftGraphView(
                            dataPoints: Self.hardcodedDriftData,
                            totalDuration: Self.hardcodedDuration
                        )
                    },
                    percentLabel: "leg straightness",
                    percentValue: "93%",
                    countLabel: "times leg drifted too far",
                    countValue: "1"
                )
                
                // Section 2: Leg Shakes / Wobbles
                analyticsSection(
                    title: "Leg Shakes / Wobbles Graph",
                    visual: {
                        ShakeGraphView(
                            dataPoints: Self.hardcodedShakeData,
                            totalDuration: Self.hardcodedDuration
                        )
                    },
                    percentLabel: "within acceptable shake",
                    percentValue: "100%",
                    countLabel: "times too much shake",
                    countValue: "0"
                )
                
                // Section 3: Too fast
                eventTimelineSection(
                    title: "Too Fast",
                    events: Self.hardcodedTooFastEvents,
                    percentLabel: "pace correct",
                    percentValue: "90%",
                    countLabel: "times too fast",
                    countValue: "1"
                )
                
                // Section 4: Too slow
                eventTimelineSection(
                    title: "Too Slow",
                    events: Self.hardcodedTooSlowEvents,
                    percentLabel: "pace correct",
                    percentValue: "90%",
                    countLabel: "times too slow",
                    countValue: "1"
                )
                
                // Section 5: Max not reached
                eventTimelineSection(
                    title: "Max Not Reached",
                    events: Self.hardcodedMaxNotReachedEvents,
                    percentLabel: "full extension",
                    percentValue: "88%",
                    countLabel: "times extend further",
                    countValue: "2"
                )
                
                // Section 6: Anterior knee migration (placeholder for knee extensions)
                eventTimelineSection(
                    title: "Anterior Knee Migration (Knee Over Toe)",
                    events: Self.hardcodedKneeOverToeEvents,
                    percentLabel: "knee behind toe",
                    percentValue: "100%",
                    countLabel: "times knee over toe",
                    countValue: "0"
                )
            }
            .padding(.bottom, 40)
        }
        .rrPageBackground()
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .swipeToGoBack()
    }
    
    private func analyticsSection<V: View>(
        title: String,
        @ViewBuilder visual: () -> V,
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            Text(title)
                .font(.rrTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
            
            visual()
                .padding(.horizontal, 16)
            
            statBoxesRow(
                percentLabel: percentLabel,
                percentValue: percentValue,
                countLabel: countLabel,
                countValue: countValue
            )
            .padding(.horizontal, 16)
        }
    }
    
    private func eventTimelineSection(
        title: String,
        events: [(rep: Int, timeSec: Double)],
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpace.stack) {
            Text(title)
                .font(.rrTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
            
            EventTimelineView(
                events: events,
                totalDuration: Self.hardcodedDuration
            )
            .padding(.horizontal, 16)
            
            statBoxesRow(
                percentLabel: percentLabel,
                percentValue: percentValue,
                countLabel: countLabel,
                countValue: countValue
            )
            .padding(.horizontal, 16)
        }
    }
    
    private func statBoxesRow(
        percentLabel: String,
        percentValue: String,
        countLabel: String,
        countValue: String
    ) -> some View {
        HStack(spacing: 12) {
            statBox(main: percentValue, caption: percentLabel)
            statBox(main: countValue, caption: countLabel)
        }
    }
    
    private func statBox(main: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(main)
                .font(.rrHeadline)
                .foregroundStyle(.primary)
            Text(caption)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemFill))
        )
    }
}

// MARK: - Hardcoded data

extension AnalyticsView {
    static let hardcodedDriftData: [(time: Double, imu: Double)] = {
        var points: [(Double, Double)] = []
        for i in stride(from: 0, through: 180, by: 2) {
            let t = Double(i)
            let imu: Double
            if t < 30 { imu = t * 0.1 }
            else if t < 60 { imu = 3 - (t - 30) * 0.1 }
            else if t < 90 { imu = -2 + (t - 60) * 0.08 }
            else if t < 115 { imu = 0.4 + (t - 90) * 0.1 }
            else if t < 135 { imu = 3.9 + (t - 115) * 0.25 }
            else if t < 180 { imu = 8.9 - (t - 135) * 0.15 }
            else { imu = 2 }
            points.append((t, imu))
        }
        return points
    }()
    
    static let hardcodedShakeData: [(time: Double, frequency: Double)] = {
        var points: [(time: Double, frequency: Double)] = []
        for i in stride(from: 0, through: 180, by: 2) {
            let t = Double(i)
            let f = 0.3 + 0.4 * sin(t * .pi / 60) + 0.1 * sin(t * .pi / 20)
            let freq = max(0.0, min(0.9, f))
            points.append((time: t, frequency: freq))
        }
        return points
    }()
    
    static let hardcodedTooFastEvents: [(rep: Int, timeSec: Double)] = [(5, 105), (7, 128)]
    static let hardcodedTooSlowEvents: [(rep: Int, timeSec: Double)] = [(8, 162)]
    static let hardcodedMaxNotReachedEvents: [(rep: Int, timeSec: Double)] = [(3, 45), (6, 95)]
    static let hardcodedKneeOverToeEvents: [(rep: Int, timeSec: Double)] = [] // placeholder
}

// MARK: - Drift Graph (IMU ±7 green/red)

struct DriftGraphView: View {
    let dataPoints: [(time: Double, imu: Double)]
    let totalDuration: Double
    
    private let imuBound: Double = 7
    private let yAxisRange: Double = 12
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let paddingLeft: CGFloat = 36
            let paddingRight: CGFloat = 8
            let paddingTop: CGFloat = 12
            let paddingBottom: CGFloat = 28
            let plotW = w - paddingLeft - paddingRight
            let plotH = h - paddingTop - paddingBottom
            let centerY = paddingTop + plotH / 2
            let halfGreenH = plotH * CGFloat(imuBound / yAxisRange) / 2
            
            ZStack(alignment: .topLeading) {
                // Zones as exact Path rects (no overlap)
                let topRedH = centerY - paddingTop - halfGreenH
                Path { p in
                    p.addRect(CGRect(x: paddingLeft, y: paddingTop, width: plotW, height: topRedH))
                }
                .fill(Color.red.opacity(0.25))
                let bottomRedH = paddingTop + plotH - centerY - halfGreenH
                Path { p in
                    p.addRect(CGRect(x: paddingLeft, y: centerY + halfGreenH, width: plotW, height: bottomRedH))
                }
                .fill(Color.red.opacity(0.25))
                
                // Green band (|y| <= 7) - on top so it’s clearly visible
                Path { p in
                    p.addRect(CGRect(x: paddingLeft, y: centerY - halfGreenH, width: plotW, height: halfGreenH * 2))
                }
                .fill(Color.green.opacity(0.4))
                
                // Axes and labels
                driftAxes(plotW: plotW, plotH: plotH, paddingLeft: paddingLeft, paddingTop: paddingTop, centerY: centerY, halfGreenH: halfGreenH)
                
                // Line
                driftLine(plotW: plotW, plotH: plotH, paddingLeft: paddingLeft, paddingTop: paddingTop)
            }
        }
        .frame(height: 260)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func driftAxes(plotW: CGFloat, plotH: CGFloat, paddingLeft: CGFloat, paddingTop: CGFloat, centerY: CGFloat, halfGreenH: CGFloat) -> some View {
        Group {
            // X-axis line
            Path { p in
                p.move(to: CGPoint(x: paddingLeft, y: paddingTop + plotH / 2))
                p.addLine(to: CGPoint(x: paddingLeft + plotW, y: paddingTop + plotH / 2))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            
            // Y-axis line
            Path { p in
                p.move(to: CGPoint(x: paddingLeft, y: paddingTop))
                p.addLine(to: CGPoint(x: paddingLeft, y: paddingTop + plotH))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            
            // Y-axis labels: 7 (top red boundary), 0 (center/IMU=0), -7 (bottom red boundary)
            Text("7")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft - 12, y: centerY - halfGreenH)
            Text("0")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft - 12, y: centerY)
            Text("-7")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft - 12, y: centerY + halfGreenH)
            
            // Y labels: Left (top), Right (bottom)
            Text("Left")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft - 18, y: paddingTop + 10)
            Text("Right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft - 18, y: paddingTop + plotH - 10)
            
            // X label
            Text("Time (sec)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft + plotW / 2, y: paddingTop + plotH + 14)
            
            // X ticks (0, 30, 60, ... up to totalDuration)
            ForEach(xTickValues(totalDuration: totalDuration), id: \.self) { t in
                let x = paddingLeft + CGFloat(t / totalDuration) * plotW
                Text("\(Int(t))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .position(x: x, y: paddingTop + plotH + 6)
            }
        }
    }
    
    private func xTickValues(totalDuration: Double) -> [Double] {
        let step: Double = totalDuration <= 120 ? 30 : (totalDuration <= 300 ? 60 : 120)
        return stride(from: 0.0, through: totalDuration, by: step).map { $0 }
    }
    
    private func driftLine(plotW: CGFloat, plotH: CGFloat, paddingLeft: CGFloat, paddingTop: CGFloat) -> some View {
        let scaleX = plotW / CGFloat(totalDuration)
        let scaleY = plotH / CGFloat(2 * yAxisRange)
        let centerY = paddingTop + plotH / 2
        var path = Path()
        if let first = dataPoints.first {
            path.move(to: CGPoint(x: paddingLeft + CGFloat(first.time) * scaleX, y: centerY - CGFloat(first.imu) * scaleY))
            for p in dataPoints.dropFirst() {
                path.addLine(to: CGPoint(x: paddingLeft + CGFloat(p.time) * scaleX, y: centerY - CGFloat(p.imu) * scaleY))
            }
        }
        return path.stroke(Color.black, lineWidth: 2)
    }
}

// MARK: - Shake Graph (frequency: green at bottom, red above)

private let shakeThreshold: Double = 0.85

struct ShakeGraphView: View {
    let dataPoints: [(time: Double, frequency: Double)]
    let totalDuration: Double
    
    private let maxFreq: Double = 1.2
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let paddingLeft: CGFloat = 36
            let paddingRight: CGFloat = 8
            let paddingTop: CGFloat = 12
            let paddingBottom: CGFloat = 28
            let plotW = w - paddingLeft - paddingRight
            let plotH = h - paddingTop - paddingBottom
            
            // Green at bottom (0 to threshold), red at top (above threshold)
            let greenH = plotH * CGFloat(shakeThreshold / maxFreq)
            let greenTop = paddingTop + plotH - greenH
            
            ZStack(alignment: .topLeading) {
                // Red zone first (above threshold, smaller)
                Rectangle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: plotW, height: greenTop - paddingTop)
                    .position(x: paddingLeft + plotW / 2, y: (paddingTop + greenTop) / 2)
                // Green zone (below threshold, larger, touching x-axis)
                Rectangle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: plotW, height: greenH)
                    .position(x: paddingLeft + plotW / 2, y: greenTop + greenH / 2)
                
                shakeAxes(plotW: plotW, plotH: plotH, paddingLeft: paddingLeft, paddingTop: paddingTop)
                shakeLine(plotW: plotW, plotH: plotH, paddingLeft: paddingLeft, paddingTop: paddingTop)
            }
        }
        .frame(height: 200)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func shakeAxes(plotW: CGFloat, plotH: CGFloat, paddingLeft: CGFloat, paddingTop: CGFloat) -> some View {
        Group {
            Path { p in
                p.move(to: CGPoint(x: paddingLeft, y: paddingTop))
                p.addLine(to: CGPoint(x: paddingLeft, y: paddingTop + plotH))
                p.move(to: CGPoint(x: paddingLeft, y: paddingTop + plotH))
                p.addLine(to: CGPoint(x: paddingLeft + plotW, y: paddingTop + plotH))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            // Frequency label rotated 90° vertical
            Text("Frequency")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(-90))
                .frame(width: 20, height: 80)
                .position(x: paddingLeft - 20, y: paddingTop + plotH / 2)
            Text("Time (sec)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft + plotW / 2, y: paddingTop + plotH + 14)
            // X-axis ticks: 0 and 180
            Text("0")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft, y: paddingTop + plotH + 6)
            Text("180")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: paddingLeft + plotW, y: paddingTop + plotH + 6)
        }
    }
    
    private func shakeLine(plotW: CGFloat, plotH: CGFloat, paddingLeft: CGFloat, paddingTop: CGFloat) -> some View {
        let scaleX = plotW / CGFloat(totalDuration)
        let scaleY = plotH / CGFloat(maxFreq)
        var path = Path()
        if let first = dataPoints.first {
            path.move(to: CGPoint(x: paddingLeft + CGFloat(first.time) * scaleX, y: paddingTop + plotH - CGFloat(first.frequency) * scaleY))
            for p in dataPoints.dropFirst() {
                path.addLine(to: CGPoint(x: paddingLeft + CGFloat(p.time) * scaleX, y: paddingTop + plotH - CGFloat(p.frequency) * scaleY))
            }
        }
        return path.stroke(Color.black, lineWidth: 2)
    }
}

// MARK: - Event Timeline (horizontal bar, red markers, Rep N • M:SS)

struct EventTimelineView: View {
    let events: [(rep: Int, timeSec: Double)]
    let totalDuration: Double
    
    @State private var frontIndex: Int? = nil
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 100
            let paddingH: CGFloat = 8
            let lineY = h - 24
            let plotW = w - 2 * paddingH
            
            ZStack(alignment: .topLeading) {
                // Timeline bar
                Path { p in
                    p.move(to: CGPoint(x: paddingH, y: lineY))
                    p.addLine(to: CGPoint(x: paddingH + plotW, y: lineY))
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                
                // X ticks
                ForEach(xTickValues(totalDuration: totalDuration), id: \.self) { t in
                    let x = paddingH + CGFloat(t / totalDuration) * plotW
                    Text("\(Int(t))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .position(x: x, y: lineY + 14)
                }
                
                // Total duration label at end
                Text(formatDuration(Int(totalDuration)))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .position(x: paddingH + plotW + 24, y: lineY + 14)
                
                // Event markers (tap brings to front)
                ForEach(Array(events.enumerated()), id: \.offset) { idx, ev in
                    let x = paddingH + CGFloat(ev.timeSec / totalDuration) * plotW
                    VStack(spacing: 2) {
                        Text("Rep \(ev.rep) • \(formatDuration(Int(ev.timeSec)))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.08), radius: 4)
                            )
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .position(x: x, y: lineY - 38)
                    .zIndex(frontIndex == idx ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        frontIndex = idx
                    }
                }
            }
        }
        .frame(height: 100)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func xTickValues(totalDuration: Double) -> [Double] {
        let step: Double = totalDuration <= 120 ? 30 : (totalDuration <= 300 ? 60 : 120)
        return stride(from: 0.0, through: totalDuration, by: step).map { $0 }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):\(s < 10 ? "0" : "")\(s)"
    }
}
