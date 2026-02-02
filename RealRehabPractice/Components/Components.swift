//
//  Components.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 11/2/25.
//

import SwiftUI
import Combine

// MARK: - Brand Colors (shared)
extension Color {
    static let brandLightBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let brandDarkBlue  = Color(red: 0.1, green: 0.2, blue: 0.6)
    /// Darker blue for lesson bubble underside (solid, hides connector line).
    static let brandDarkerBlue = Color(red: 0.05, green: 0.1, blue: 0.42)
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

// MARK: - Glossy Lesson Bubble (oval 3D token style)
/// Reusable oval (wider than tall), 3D beveled, glossy. Height 75pt; underside is solid darker blue so connector line doesn’t show.
/// Shine: two diagonal low-opacity white stripes at 45°, clipped to capsule.
struct GlossyLessonBubbleBackground: View {
    var baseColor: Color = .brandDarkBlue
    /// Oval wider than tall: height 75pt, width 88pt.
    private let ovalWidth: CGFloat = 88
    private let ovalHeight: CGFloat = 75
    private let hitSize: CGFloat = 88

    var body: some View {
        ZStack {
            // 1) Darker underside (solid 100% opacity so connector line doesn’t show); larger offset for clickable look
            Capsule()
                .fill(Color.brandDarkerBlue)
                .frame(width: ovalWidth, height: ovalHeight)
                .offset(y: 6)
                .blur(radius: 0)

            // 2) Base oval
            Capsule()
                .fill(baseColor)
                .frame(width: ovalWidth, height: ovalHeight)

            // 3) Vertical lighting + subtle inner shadow at bottom edge (bevel)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: ovalWidth, height: ovalHeight)
                .allowsHitTesting(false)

            // 4) Shine: two 45° diagonal white low-opacity stripes, clipped to bubble
            ZStack {
                // Center stripe (wider)
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 12, height: diagonalStripeLength)
                    .rotationEffect(.degrees(45))
                // Above-left stripe (thinner), parallel
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 6, height: diagonalStripeLength)
                    .rotationEffect(.degrees(45))
                    .offset(x: -10, y: -10)
            }
            .frame(width: ovalWidth, height: ovalHeight)
            .clipShape(Capsule())
            .allowsHitTesting(false)

            // 5) Top-edge rim highlight + bottom-edge darker rim (bevel)
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.15),
                            Color.clear,
                            baseColor.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.1
                )
                .frame(width: ovalWidth, height: ovalHeight)
                .allowsHitTesting(false)
        }
        .frame(width: hitSize, height: hitSize)
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .shadow(color: baseColor.opacity(0.35), radius: 12, x: 0, y: 3)
    }

    /// Long enough that rotated 45° the stripe reaches the capsule edge (diagonal of bubble).
    private var diagonalStripeLength: CGFloat {
        sqrt(ovalWidth * ovalWidth + ovalHeight * ovalHeight) + 10
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
// MARK: - Bluetooth Popup Manager
class BluetoothPopupManager: ObservableObject {
    static let shared = BluetoothPopupManager()
    @Published var showPopup = false
    
    private init() {}
}

struct BluetoothStatusIndicator: View {
    @StateObject private var ble = BluetoothManager.shared
    @StateObject private var popupManager = BluetoothPopupManager.shared
    
    private var isConnected: Bool {
        ble.connectedPeripheral != nil
    }
    
    private var deviceName: String {
        ble.connectedDeviceName ?? "Unknown Device"
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                popupManager.showPopup.toggle()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                // Main icon - using "link" icon which is generic for connectivity
                Image(systemName: "link")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                
                // Status dot - reduced size by 50% (from 10 to 5)
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 5, height: 5)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.0)
                    )
                    .offset(x: 2, y: -1) // Moved left to prevent cutoff
            }
            .frame(width: 32, height: 32) // Larger frame to prevent cutoff
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bluetooth Popup Overlay Modifier
struct BluetoothPopupOverlay: ViewModifier {
    @StateObject private var popupManager = BluetoothPopupManager.shared
    @StateObject private var ble = BluetoothManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if popupManager.showPopup {
                    BluetoothPopupView()
                }
            }
    }
}

private struct BluetoothPopupView: View {
    @StateObject private var popupManager = BluetoothPopupManager.shared
    @StateObject private var ble = BluetoothManager.shared
    
    private var isConnected: Bool {
        ble.connectedPeripheral != nil
    }
    
    private var deviceName: String {
        "RealRehab Knee Brace"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background overlay to capture taps outside
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            popupManager.showPopup = false
                        }
                    }
                
                // Popup content positioned below navigation bar
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.safeAreaInsets.top + 44) // Navigation bar height + safe area
                    
                    popupContent
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
            }
        }
        .transition(.opacity)
    }
    
    private var popupContent: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .overlay {
                VStack(spacing: 16) {
                    if isConnected {
                        // Show kneebrace image when connected
                        Image("kneebrace")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Text(deviceName)
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        // Disconnect button
                        Button {
                            ble.disconnect()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                popupManager.showPopup = false
                            }
                        } label: {
                            Text("Disconnect")
                                .font(.rrBody)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                        }
                    } else {
                        Text("No Device Connected")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity) // Same width as PTDetailView rounded rectangles (screen width - 32px padding)
            .frame(height: isConnected ? 260 : 100) // Increased height to accommodate button
    }
}

extension View {
    func bluetoothPopupOverlay() -> some View {
        modifier(BluetoothPopupOverlay())
    }
}

// MARK: - Recovery Chart (Week View)
struct RecoveryChartWeekView: View {
    let patientProfileId: UUID?  // Optional: if provided, fetch for specific patient (PT view)
    
    @State private var allCalibrationPoints: [TelemetryService.MaximumCalibrationPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showFullHistory = false
    
    init(patientProfileId: UUID? = nil) {
        self.patientProfileId = patientProfileId
    }
    
    // Miami, Florida timezone calendar helper
    private var miamiCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
        return calendar
    }
    
    // Get current week range (Sunday to Saturday) in Miami timezone
    private var currentWeekRange: (start: Date, end: Date) {
        let calendar = miamiCalendar
        let now = Date()
        
        // Get current date components in Miami timezone
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: now)
        
        // Find the start of the week (Sunday) in Miami timezone
        guard let weekday = components.weekday else {
            // Fallback
            let fallbackCalendar = Calendar.current
            let weekday = fallbackCalendar.component(.weekday, from: now)
            let daysFromSunday = (weekday == 1) ? 0 : (weekday - 1)
            let startOfWeek = fallbackCalendar.date(byAdding: .day, value: -daysFromSunday, to: now)!
            let startOfWeekStart = fallbackCalendar.startOfDay(for: startOfWeek)
            let endOfWeek = fallbackCalendar.date(byAdding: .day, value: 6, to: startOfWeekStart)!
            let endOfWeekEnd = fallbackCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek)!
            return (start: startOfWeekStart, end: endOfWeekEnd)
        }
        
        let daysFromSunday = (weekday == 1) ? 0 : (weekday - 1) // Sunday is 1
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: now) else {
            // Fallback
            let fallbackCalendar = Calendar.current
            let weekday = fallbackCalendar.component(.weekday, from: now)
            let daysFromSunday = (weekday == 1) ? 0 : (weekday - 1)
            let startOfWeek = fallbackCalendar.date(byAdding: .day, value: -daysFromSunday, to: now)!
            let startOfWeekStart = fallbackCalendar.startOfDay(for: startOfWeek)
            let endOfWeek = fallbackCalendar.date(byAdding: .day, value: 6, to: startOfWeekStart)!
            let endOfWeekEnd = fallbackCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek)!
            return (start: startOfWeekStart, end: endOfWeekEnd)
        }
        
        let startOfWeekStart = calendar.startOfDay(for: startOfWeek)
        
        // Find the end of the week (Saturday) in Miami timezone
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeekStart),
              let endOfWeekEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) else {
            // Fallback
            let fallbackCalendar = Calendar.current
            let weekday = fallbackCalendar.component(.weekday, from: now)
            let daysFromSunday = (weekday == 1) ? 0 : (weekday - 1)
            let startOfWeek = fallbackCalendar.date(byAdding: .day, value: -daysFromSunday, to: now)!
            let startOfWeekStart = fallbackCalendar.startOfDay(for: startOfWeek)
            let endOfWeek = fallbackCalendar.date(byAdding: .day, value: 6, to: startOfWeekStart)!
            let endOfWeekEnd = fallbackCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek)!
            return (start: startOfWeekStart, end: endOfWeekEnd)
        }
        
        return (start: startOfWeekStart, end: endOfWeekEnd)
    }
    
    // Filter calibration points to current week only
    // Stage filtering already done in TelemetryService - rely on database stage column
    private var weekCalibrationPoints: [TelemetryService.MaximumCalibrationPoint] {
        let weekRange = currentWeekRange
        return allCalibrationPoints.filter { point in
            // Filter by week range only - stage filtering already done in TelemetryService
            point.recordedAt >= weekRange.start && point.recordedAt <= weekRange.end
        }
    }
    
    // Get all 7 days of the week with their day of month labels (Miami timezone)
    private var weekDayLabels: [(dayOfWeek: Int, dayOfMonth: Int, date: Date)] {
        let calendar = miamiCalendar
        let weekRange = currentWeekRange
        var labels: [(dayOfWeek: Int, dayOfMonth: Int, date: Date)] = []
        
        for dayOffset in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekRange.start) {
                let dayOfWeek = calendar.component(.weekday, from: dayDate) - 1 // Convert to 0-6 (Sunday=0)
                let dayOfMonth = calendar.component(.day, from: dayDate)
                labels.append((dayOfWeek: dayOfWeek, dayOfMonth: dayOfMonth, date: dayDate))
            }
        }
        
        return labels.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }
    
    // Convert calibration points to chart data format for current week (Miami timezone)
    // Show ALL points, not just one per day
    private var chartData: [(dayOfMonth: Int, degrees: Double, date: Date)] {
        let calendar = miamiCalendar
        
        // Convert all points, preserving all of them (no grouping)
        return weekCalibrationPoints.map { point in
            // Extract day of month in Miami timezone explicitly
            // The calendar's timezone is already set to Miami, so component() will use it
            let components = calendar.dateComponents([.day], from: point.recordedAt)
            let dayOfMonth = components.day ?? 1
            return (dayOfMonth: dayOfMonth, degrees: Double(point.degrees), date: point.recordedAt)
        }
        .sorted { $0.date < $1.date } // Sort chronologically
    }
    
    // Calculate week range string for display (Miami timezone)
    private var weekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = miamiCalendar.timeZone
        
        let weekRange = currentWeekRange
        let startDay = formatter.string(from: weekRange.start)
        let endDay = formatter.string(from: weekRange.end)
        
        return "\(startDay) - \(endDay)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress this week")
                .font(.rrTitle)
                .padding(.horizontal, 16)
            
            Button {
                showFullHistory = true
            } label: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else if chartData.isEmpty {
                            // Check if there's any past data
                            if allCalibrationPoints.isEmpty {
                                // No data at all
                                Text("No Data")
                                    .font(.rrBody)
                                    .foregroundStyle(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                // Has past data but none for this week
                                VStack(spacing: 8) {
                                    Text("No data this week")
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                    Text("Tap to view full history")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary.opacity(0.7))
                                }
                                .multilineTextAlignment(.center)
                            }
                        } else {
                            ChartContentView(
                                data: chartData.map { ($0.dayOfMonth, $0.degrees) },
                                isWeekView: true,
                                weekRange: weekRange,
                                timestamps: chartData.map { $0.date },
                                weekDayLabels: weekDayLabels.map { ($0.dayOfMonth, $0.date) },
                                isFullHistory: false,
                                fullHistoryLabels: nil
                            )
                        }
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showFullHistory) {
            RecoveryChartFullHistoryView(
                calibrationPoints: allCalibrationPoints,
                patientProfileId: patientProfileId
            )
        }
        .task {
            await loadCalibrationData()
        }
    }
    
    private func loadCalibrationData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let points: [TelemetryService.MaximumCalibrationPoint]
            if let patientProfileId = patientProfileId {
                // Fetch for specific patient (PT view)
                points = try await TelemetryService.getAllMaximumCalibrationsForPatient(patientProfileId: patientProfileId)
            } else {
                // Fetch for current patient (patient view)
                points = try await TelemetryService.getAllMaximumCalibrationsForPatient()
            }
            
            await MainActor.run {
                allCalibrationPoints = points
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load calibration data: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Recovery Chart (Full History View)
struct RecoveryChartFullHistoryView: View {
    let calibrationPoints: [TelemetryService.MaximumCalibrationPoint]
    let patientProfileId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    // Miami, Florida timezone calendar helper
    private var miamiCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
        return calendar
    }
    
    // Convert all calibration points to chart data (Miami timezone)
    // Show ALL points, not just one per day
    // Stage filtering already done in TelemetryService - rely on database stage column
    private var chartData: [(day: Int, month: String, degrees: Double, date: Date)] {
        let calendar = miamiCalendar
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.timeZone = calendar.timeZone
        
        // No degree filtering - rely only on stage column from database
        return calibrationPoints.map { point in
            let components = calendar.dateComponents([.day, .month], from: point.recordedAt)
            let day = components.day ?? 1
            let month = formatter.string(from: point.recordedAt)
            return (day: day, month: month, degrees: Double(point.degrees), date: point.recordedAt)
        }
        .sorted { $0.date < $1.date } // Sort chronologically
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .frame(width: max(geometry.size.width, CGFloat(chartData.count) * 60), height: 400)
                            .padding()
                            .overlay {
                                if chartData.isEmpty {
                                    Text("No Data")
                                        .font(.rrBody)
                                        .foregroundStyle(.gray)
                                        .multilineTextAlignment(.center)
                                } else {
                                    ChartContentView(
                                        data: chartData.map { ($0.day, $0.degrees) },
                                        isWeekView: false,
                                        weekRange: nil,
                                        timestamps: chartData.map { $0.date },
                                        weekDayLabels: nil,
                                        isFullHistory: true,
                                        fullHistoryLabels: chartData.map { ($0.day, $0.month, $0.date) }
                                    )
                                }
                            }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Full Progress History")
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
                            weekRange: nil,
                            timestamps: nil,
                            weekDayLabels: nil,
                            isFullHistory: false,
                            fullHistoryLabels: nil
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
    let timestamps: [Date]?  // Optional timestamps for proper spacing
    let weekDayLabels: [(dayOfMonth: Int, date: Date)]?  // Optional: all 7 days of week with labels for week view
    let isFullHistory: Bool  // Whether this is the full history view
    let fullHistoryLabels: [(day: Int, month: String, date: Date)]?  // Optional: full history labels with month info
    
    init(
        data: [(day: Int, degrees: Double)],
        isWeekView: Bool,
        weekRange: String?,
        timestamps: [Date]?,
        weekDayLabels: [(dayOfMonth: Int, date: Date)]? = nil,
        isFullHistory: Bool = false,
        fullHistoryLabels: [(day: Int, month: String, date: Date)]? = nil
    ) {
        self.data = data
        self.isWeekView = isWeekView
        self.weekRange = weekRange
        self.timestamps = timestamps
        self.weekDayLabels = weekDayLabels
        self.isFullHistory = isFullHistory
        self.fullHistoryLabels = fullHistoryLabels
    }
    
    private var dataMinDegrees: Double {
        data.map { $0.degrees }.min() ?? 0
    }
    
    private var dataMaxDegrees: Double {
        data.map { $0.degrees }.max() ?? 100
    }
    
    // Calculate Y-axis range with dynamic increments starting ~10 degrees below minimum
    private func calculateYAxisRange() -> (min: Double, max: Double, increment: Double, labels: [Double]) {
        let dataMin = dataMinDegrees
        let dataMax = dataMaxDegrees
        let range = dataMax - dataMin
        
        // Start ~10 degrees below minimum, rounded down to nearest 10
        let axisMin = floor((dataMin - 10) / 10) * 10
        
        // Determine increment based on range
        let increment: Double
        if range < 50 {
            increment = 10
        } else if range < 100 {
            increment = 20
        } else if range < 200 {
            increment = 25
        } else {
            increment = 50
        }
        
        // Calculate max to show (ensure we have enough range above data)
        let axisMax = ceil((dataMax + 10) / increment) * increment
        
        // Generate Y-axis labels
        var labels: [Double] = []
        var current = axisMin
        while current <= axisMax {
            labels.append(current)
            current += increment
        }
        
        return (min: axisMin, max: axisMax, increment: increment, labels: labels)
    }
    
    private var yAxisInfo: (min: Double, max: Double, increment: Double, labels: [Double]) {
        calculateYAxisRange()
    }
    
    private var degreesRange: Double {
        yAxisInfo.max - yAxisInfo.min
    }
    
    // Calculate the full day range (from earliest to latest day, including all days in between)
    // Also includes one extra day after the latest day for spacing points on the last day
    private var fullDayRange: [Int] {
        // If weekDayLabels is provided (for week view), use all 7 days
        if let weekDayLabels = weekDayLabels, isWeekView {
            let days = weekDayLabels.map { $0.dayOfMonth }.sorted()
            if let lastDay = days.last {
                var result = days
                result.append(lastDay + 1) // Add next day for spacing points on the last day
                return result
            }
            return days
        }
        
        // For full history mode, use all unique days from data
        if isFullHistory {
            let uniqueDays = Set(data.map { $0.day }).sorted()
            guard let firstDay = uniqueDays.first,
                  let lastDay = uniqueDays.last else {
                return uniqueDays
            }
            // Return all days from first to last, inclusive, plus one extra day for spacing
            var days = Array(firstDay...lastDay)
            days.append(lastDay + 1) // Add next day for spacing points on the last day
            return days
        }
        
        // Otherwise, use the data-based range
        let uniqueDays = Set(data.map { $0.day }).sorted()
        guard let firstDay = uniqueDays.first,
              let lastDay = uniqueDays.last else {
            return uniqueDays
        }
        // Return all days from first to last, inclusive, plus one extra day for spacing
        var days = Array(firstDay...lastDay)
        days.append(lastDay + 1) // Add next day for spacing points on the last day
        return days
    }
    
    // Calculate X positions with points positioned AFTER their day label
    private func xPosition(for index: Int, in chartWidth: CGFloat) -> CGFloat {
        // For full history mode, use chronological spacing
        if isFullHistory {
            let numPoints = CGFloat(data.count)
            let usableWidth = chartWidth - 60
            let pointSpacing = numPoints > 1 ? usableWidth / (numPoints - 1) : 0
            return 30 + (CGFloat(index) * pointSpacing)
        }
        
        // For week view with single point, position it over the correct day using timestamp
        if isWeekView, data.count == 1, let timestamps = timestamps, let weekDayLabels = weekDayLabels, index < timestamps.count {
            let pointDate = timestamps[index]
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
            
            // Get day of month from the timestamp in Miami timezone
            let pointDay = calendar.component(.day, from: pointDate)
            
            // Find which day of week this corresponds to
            if let dayIndex = weekDayLabels.firstIndex(where: { $0.dayOfMonth == pointDay }) {
                let numDays = CGFloat(weekDayLabels.count)
                let usableWidth = chartWidth - 60
                let dayLabelSpacing = usableWidth / (numDays > 1 ? numDays - 1 : 1)
                return 30 + (CGFloat(dayIndex) * dayLabelSpacing)
            }
        }
        
        guard data.count > 1 else {
            // Fall back to center only if we can't find the day
            return 30 + (chartWidth - 60) / 2
        }
        
        // Get full day range (includes all days from earliest to latest)
        let allDays = fullDayRange
        guard !allDays.isEmpty else {
            // Fallback
            let dayLabelWidth = (chartWidth - 60) / CGFloat(data.count)
            return 30 + (CGFloat(index) * dayLabelWidth)
        }
        
        // Group points by day
        var dayGroups: [Int: [Int]] = [:] // day -> array of indices
        for (idx, point) in data.enumerated() {
            if dayGroups[point.day] == nil {
                dayGroups[point.day] = []
            }
            dayGroups[point.day]?.append(idx)
        }
        
        // Calculate spacing: evenly distribute all days across the chart
        let numDays = CGFloat(allDays.count)
        let usableWidth = chartWidth - 60  // 30px padding on left and right
        let dayLabelSpacing = usableWidth / (numDays > 1 ? numDays - 1 : 1) // Space between day labels
        
        // Find which day this point belongs to
        let currentDay = data[index].day
        guard let dayIndex = allDays.firstIndex(of: currentDay),
              let dayIndices = dayGroups[currentDay] else {
            // Fallback
            let dayLabelWidth = (chartWidth - 60) / CGFloat(data.count)
            return 30 + (CGFloat(index) * dayLabelWidth)
        }
        
        // Find position within the day's group
        let sortedDayIndices = dayIndices.sorted()
        guard let positionInDay = sortedDayIndices.firstIndex(of: index) else {
            // Fallback
            let dayLabelWidth = (chartWidth - 60) / CGFloat(data.count)
            return 30 + (CGFloat(index) * dayLabelWidth)
        }
        
        // Position of the day's label (at origin for first day, evenly spaced for others)
        let dayLabelX = 30 + (CGFloat(dayIndex) * dayLabelSpacing)
        
        // Calculate segment width: all days use the same spacing to next day's label
        // This includes the last day which now has an extra day label after it for spacing
        let daySegmentWidth = dayLabelSpacing
        
        // Position points AFTER the day label using formula: 1/(1+v), 2/(1+v), ..., v/(1+v)
        // where v is the number of values (points) on that day
        let numPointsOnDay = CGFloat(dayIndices.count) // This is v
        let spacingRatio = 1.0 / (1.0 + numPointsOnDay) // This is 1/(1+v)
        
        // Calculate position: (positionInDay + 1) * spacingRatio
        // For v=2: positions at 1/3 and 2/3
        // For v=3: positions at 1/4, 2/4, 3/4
        let relativePositionInDay = CGFloat(positionInDay + 1) * spacingRatio
        
        // Calculate x position: day label position + offset into the segment
        let x = dayLabelX + (relativePositionInDay * daySegmentWidth)
        
        // Ensure we don't exceed chart boundaries (with padding)
        let chartRightEdge = 30 + usableWidth
        return min(x, chartRightEdge - 10) // Leave 10px padding from right edge
    }
    
    // Get all days in range and their positions for x-axis labels (evenly spaced)
    // Excludes the extra day added for spacing (only show actual data days)
    private func uniqueDayPositions(in chartWidth: CGFloat) -> [(day: Int, x: CGFloat)] {
        // Get full day range (includes all days from earliest to latest, plus extra day)
        let allDays = fullDayRange
        guard !allDays.isEmpty else {
            return []
        }
        
        // Remove the extra day (last item) for display purposes
        let displayDays = Array(allDays.dropLast())
        
        // Calculate spacing: evenly distribute all days (including the extra one for spacing calculations)
        let numDays = CGFloat(allDays.count)
        let usableWidth = chartWidth - 60  // 30px padding on left and right
        let dayLabelSpacing = usableWidth / (numDays > 1 ? numDays - 1 : 1) // Space between day labels
        
        // Position labels evenly: first day at origin (30), others evenly spaced
        // Only show actual data days, not the extra spacing day
        var result: [(day: Int, x: CGFloat)] = []
        for (dayIndex, day) in displayDays.enumerated() {
            let x = 30 + (CGFloat(dayIndex) * dayLabelSpacing)
            result.append((day: day, x: x))
        }
        
        return result
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
                        // Y-axis grid lines and labels (using dynamic calculation)
                        let yLabels = yAxisInfo.labels
                        ForEach(Array(yLabels.enumerated()), id: \.offset) { index, value in
                            // Calculate Y position: normalize value to 0-1 range, then map to chart height
                            let normalizedValue = degreesRange > 0 ? (value - yAxisInfo.min) / degreesRange : 0.5
                            let y = CGFloat(normalizedValue) * chartHeight
                            
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
                            .offset(y: chartHeight - y) // Flip Y axis (0 at bottom)
                        }
                        
                        // Plot line
                        Path { path in
                            for (index, point) in data.enumerated() {
                                let x = xPosition(for: index, in: chartWidth)
                                // Normalize using Y-axis range (not data range)
                                let normalizedDegrees = degreesRange > 0 ? (point.degrees - yAxisInfo.min) / degreesRange : 0.5
                                let y = CGFloat(normalizedDegrees) * chartHeight
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: chartHeight - y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: chartHeight - y))
                                }
                            }
                        }
                        .stroke(Color.brandDarkBlue, lineWidth: 2)
                        
                        // Plot points - positioned based on timestamps
                        ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                            let x = xPosition(for: index, in: chartWidth)
                            // Normalize using Y-axis range (not data range)
                            let normalizedDegrees = degreesRange > 0 ? (point.degrees - yAxisInfo.min) / degreesRange : 0.5
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
                        // Week view: show all 7 days of the week
                        ZStack {
                            if let weekDayLabels = weekDayLabels {
                                // Show all 7 days, even if no data
                                let numDays = CGFloat(weekDayLabels.count)
                                let usableWidth = chartWidth - 60
                                let dayLabelSpacing = usableWidth / (numDays > 1 ? numDays - 1 : 1)
                                
                                ForEach(Array(weekDayLabels.enumerated()), id: \.offset) { index, label in
                                    let x = 30 + (CGFloat(index) * dayLabelSpacing)
                                    
                                    Text("\(label.dayOfMonth)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .position(x: x, y: 10)
                                }
                            } else {
                                // Fallback to original behavior
                                ForEach(uniqueDayPositions(in: chartWidth), id: \.day) { dayPosition in
                                    Text("\(dayPosition.day)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .position(x: dayPosition.x, y: 10)
                                }
                            }
                        }
                        .frame(width: chartWidth, height: 20)
                    } else if isFullHistory, let fullHistoryLabels = fullHistoryLabels {
                        // Full history view: show day numbers with month indicators
                        ZStack {
                            let numPoints = CGFloat(fullHistoryLabels.count)
                            let usableWidth = chartWidth - 60
                            let pointSpacing = numPoints > 1 ? usableWidth / (numPoints - 1) : 0
                            
                            ForEach(Array(fullHistoryLabels.enumerated()), id: \.offset) { index, label in
                                let x = 30 + (CGFloat(index) * pointSpacing)
                                
                                // Show month in parentheses when month changes
                                let showMonth = index == 0 || fullHistoryLabels[index - 1].month != label.month
                                
                                VStack(spacing: 2) {
                                    Text("\(label.day)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    
                                    if showMonth {
                                        Text("(\(label.month))")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary.opacity(0.7))
                                    }
                                }
                                .position(x: x, y: showMonth ? 18 : 10)
                            }
                        }
                        .frame(width: chartWidth, height: 30)
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
    let completedDays: Int  // Allow customization, default 1 for patient view
    
    init(completedDays: Int = 1) {
        self.completedDays = completedDays
    }
    
    private var totalDaysInMonth: Int {
        // Always show 31 dots (full calendar grid)
        return 31
    }
    
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
