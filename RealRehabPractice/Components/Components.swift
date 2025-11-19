//
//  Components.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 11/2/25.
//

import SwiftUI

// MARK: - Brand Colors (shared)
extension Color {
    static let brandLightBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let brandDarkBlue  = Color(red: 0.1, green: 0.2, blue: 0.6)
}

// MARK: - Primary (Filled) Button
struct PrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    var useLargeFont: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(useLargeFont ? .rrTitle : .rrBody)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(isDisabled ? Color.gray : .brandDarkBlue)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Secondary (Outline) Button
struct SecondaryButton: View {
    let title: String
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rrBody)
                .foregroundStyle(isDisabled ? Color.gray : .brandDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isDisabled ? Color.gray : .brandDarkBlue, lineWidth: 2)
                )
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Step Indicator (with label + connected dots)
struct StepIndicator: View {
    let current: Int
    let total: Int
    var showLabel: Bool = true

    private let active = Color.brandLightBlue
    private let inactive = Color.gray.opacity(0.3)

    var body: some View {
        VStack(spacing: 8) {
            if showLabel {
                Text("Step \(current)")
                    .font(.rrTitle)
            }

            HStack(spacing: 16) {
                ForEach(1...total, id: \.self) { step in
                    HStack(spacing: 0) {
                        Circle()
                            .fill(step <= current ? active : inactive)
                            .frame(width: 10, height: 10)

                        if step < total {
                            Rectangle()
                                .fill(step < current ? active : inactive)
                                .frame(width: 40, height: 2)
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Back Button (Toolbar-compatible)
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var title: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            if let action { action() }
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.rrBody)
                if let title {
                    Text(title)
                        .font(.rrBody)
                }
            }
        }
        .foregroundColor(Color.brandDarkBlue) // ✅ FIXED: explicitly declare Color
        .accessibilityLabel(title ?? "Back")
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.rrBody)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search")
    }
}

// MARK: - BodyPartCard
struct BodyPartCard: View {
    let title: String
    var image: Image? = nil
    var imageName: String? = nil
    var tappable: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Image block
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 160, height: 160)
                .overlay(
                    Group {
                        if let image = image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if let imageName = imageName {
                            Image(imageName, bundle: .main)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "photo")
                                .font(.rrBody)
                                .foregroundStyle(.gray)
                        }
                    }
                )

            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.primary)
                .frame(maxWidth: 160, alignment: .center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if tappable { action?() }
        }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
    }
}

// MARK: - Bluetooth Status Indicator
struct BluetoothStatusIndicator: View {
    @StateObject private var ble = BluetoothManager.shared
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main icon - using "link" icon which is generic for connectivity
            Image(systemName: "link")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
            
            // Status dot
            Circle()
                .fill(ble.connectedPeripheral != nil ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .offset(x: 6, y: -2)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Recovery Chart (Week View)
struct RecoveryChartWeekView: View {
    // Hardcoded data for December 2-5 (4 consecutive days, +5 degrees each)
    private let weekData: [(day: Int, degrees: Double)] = [
        (2, 45.0),
        (3, 50.0),
        (4, 55.0),
        (5, 60.0)
    ]
    
    private let weekRange = "Dec 2-8"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress this week")
                .font(.rrTitle)
                .padding(.horizontal, 16)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .overlay {
                    ChartContentView(
                        data: weekData,
                        isWeekView: true,
                        weekRange: weekRange
                    )
                }
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Recovery Chart (Month View) - Not currently used
struct RecoveryChartMonthView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Hardcoded data for entire December (sample data)
    private let monthData: [(day: Int, degrees: Double)] = [
        (1, 42.0), (2, 45.0), (3, 48.0), (4, 52.0),
        (5, 50.0), (6, 58.0), (7, 55.0), (8, 65.0),
        (9, 63.0), (10, 68.0), (11, 70.0), (12, 72.0),
        (13, 75.0), (14, 73.0), (15, 78.0), (16, 80.0),
        (17, 82.0), (18, 85.0), (19, 83.0), (20, 88.0),
        (21, 90.0), (22, 92.0), (23, 95.0), (24, 93.0),
        (25, 98.0), (26, 100.0), (27, 102.0), (28, 105.0),
        (29, 103.0), (30, 108.0), (31, 110.0)
    ]
    
    var body: some View {
        NavigationStack {
            VStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .padding()
                    .overlay {
                        ChartContentView(
                            data: monthData,
                            isWeekView: false,
                            weekRange: nil
                        )
                    }
                
                Spacer()
            }
            .navigationTitle("December Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chart Content View
struct ChartContentView: View {
    let data: [(day: Int, degrees: Double)]
    let isWeekView: Bool
    let weekRange: String?
    
    private var minDegrees: Double {
        data.map { $0.degrees }.min() ?? 0
    }
    
    private var maxDegrees: Double {
        data.map { $0.degrees }.max() ?? 100
    }
    
    private var degreesRange: Double {
        maxDegrees - minDegrees
    }
    
    var body: some View {
        GeometryReader { geometry in
            let yAxisLabelWidth: CGFloat = 25 // Reduced for more graph space
            let chartWidth = geometry.size.width - yAxisLabelWidth - 4 // Reduced padding
            let chartHeight = geometry.size.height - 50 // Padding for X-axis
            
            VStack(spacing: 0) {
                // Y-axis label and chart area
                HStack(alignment: .center, spacing: 1) {
                    // Y-axis label (centered vertically, single line)
                    VStack {
                        Spacer()
                        Text("Range of Motion (degrees)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                            .frame(width: yAxisLabelWidth - 1)
                        Spacer()
                    }
                    
                    // Chart area
                    ZStack(alignment: .topLeading) {
                        // Y-axis grid lines and labels
                        ForEach(0..<5) { i in
                            let y = CGFloat(i) * (chartHeight / 4)
                            let value = maxDegrees - (Double(i) * degreesRange / 4)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("\(Int(value))")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                    
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 1)
                                }
                                
                                Spacer()
                            }
                            .frame(height: chartHeight)
                            .offset(y: y)
                        }
                        
                        // Calculate x positions to align with day labels
                        let dayLabelWidth = (chartWidth - 30) / CGFloat(data.count)
                        let firstDayX = 30 + (dayLabelWidth / 2)
                        
                        // Plot line
                        Path { path in
                            for (index, point) in data.enumerated() {
                                let x = firstDayX + CGFloat(index) * dayLabelWidth
                                let normalizedDegrees = degreesRange > 0 ? (point.degrees - minDegrees) / degreesRange : 0.5
                                let y = CGFloat(normalizedDegrees) * chartHeight
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: chartHeight - y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: chartHeight - y))
                                }
                            }
                        }
                        .stroke(Color.brandDarkBlue, lineWidth: 2)
                        
                        // Plot points - aligned with day labels
                        ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                            let x = firstDayX + CGFloat(index) * dayLabelWidth
                            let normalizedDegrees = degreesRange > 0 ? (point.degrees - minDegrees) / degreesRange : 0.5
                            let y = CGFloat(normalizedDegrees) * chartHeight
                            
                            Circle()
                                .fill(Color.brandDarkBlue)
                                .frame(width: 8, height: 8)
                                .position(x: x, y: chartHeight - y)
                        }
                    }
                    .frame(width: chartWidth, height: chartHeight)
                }
                .padding(.leading, 1)
                .padding(.top, 8)
                
                // X-axis label
                HStack {
                    Spacer()
                        .frame(width: yAxisLabelWidth)
                    
                    if isWeekView {
                        // Week view: show day numbers - aligned with plot points
                        HStack(spacing: 0) {
                            ForEach(data, id: \.day) { point in
                                Text("\(point.day)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(width: chartWidth - 30)
                    } else {
                        // Month view: show day numbers (scrollable)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(data, id: \.day) { point in
                                    Text("\(point.day)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .frame(width: chartWidth - 30)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 1)
                
                // X-axis title - directly under the chart
                if isWeekView, let weekRange = weekRange {
                    HStack {
                        Spacer()
                            .frame(width: yAxisLabelWidth)
                        Text("Days (\(weekRange))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Activity Consistency Card
struct ActivityConsistencyCard: View {
    // Hardcoded: 4 days completed this month
    private let completedDays = 4
    private let totalDaysInMonth = 31
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.rrTitle)
                .padding(.horizontal, 16)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .overlay {
                    HStack(spacing: 20) {
                        // Left side: Days count
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(completedDays) days")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.primary)
                            
                            Text("this month")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Right side: Calendar grid
                        CalendarBubbleGrid(completedDays: completedDays, totalDays: totalDaysInMonth)
                    }
                    .padding(20)
                }
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Calendar Bubble Grid
struct CalendarBubbleGrid: View {
    let completedDays: Int
    let totalDays: Int
    
    // Create a 7-column grid (days of week) with 31 dots total
    private let columns = 7
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 4) {
            // Day letters row
            HStack(spacing: 4) {
                ForEach(0..<columns, id: \.self) { col in
                    Text(dayLetters[col])
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 8)
                }
            }
            
            // Calendar dots (31 total, arranged in rows)
            VStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < totalDays {
                                Circle()
                                    .fill(index < completedDays ? Color.brandDarkBlue : Color.gray.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
    }
}
