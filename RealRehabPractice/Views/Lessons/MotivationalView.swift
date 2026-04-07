import SwiftUI

struct MotivationalView: View {
    let lessonId: UUID?
    @EnvironmentObject var router: Router

    @State private var startDate: Date = Date()
    @State private var message: String = ""
    @State private var textOffset: CGFloat = -800
    @State private var fadeOut: Bool = false

    private static let messages: [String] = [
        "You're getting stronger!",
        "Failure is scared of you!",
        "Well done!",
        "Beast mode!",
        "Pain is temporary. Progress is forever!",
        "Every rep counts. Every single one!",
        "You showed up. That's everything!",
        "Harder than yesterday. Better than before!",
        "Your comeback starts right now!",
        "Refuse to quit!",
        "The work you put in today compounds!",
        "Champions are built in sessions like this!"
    ]

    private let screenHeight: CGFloat = UIScreen.main.bounds.height
    private var offscreenTop: CGFloat    { -screenHeight * 0.65 }
    private var center: CGFloat          { -screenHeight * 0.20 }
    private var slowDriftEnd: CGFloat    { -screenHeight * 0.05 }
    private var offscreenBottom: CGFloat { screenHeight * 1.2 }

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.955, green: 0.955, blue: 0.990), location: 0.00),
                    .init(color: Color(red: 0.920, green: 0.925, blue: 0.975), location: 0.30),
                    .init(color: Color(red: 0.860, green: 0.872, blue: 0.955), location: 0.65),
                    .init(color: Color(red: 0.800, green: 0.820, blue: 0.935), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            confettiCanvas

            Text(message)
                .font(.system(size: 42, weight: .heavy, design: .default).italic())
                .foregroundStyle(Color.brandDarkBlue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .offset(y: textOffset)

            if fadeOut {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            message = Self.messages.randomElement() ?? Self.messages[0]
            startDate = Date()
            textOffset = offscreenTop
            Task { await runTextAnimation() }
        }
    }

    // MARK: - Text Animation

    private func runTextAnimation() async {
        // Phase 1: fast slide in from top (0.45s easeOut)
        await animate(0.45, .easeOut) { textOffset = center }
        // Phase 2: slow drift through center (3.5s linear — readable window)
        await animate(3.5,  .linear)  { textOffset = slowDriftEnd }
        // Phase 3: fast slide off to bottom (0.45s easeIn)
        await animate(0.45, .easeIn)  { textOffset = offscreenBottom }
        // Brief pause, then fade to white
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.35)) { fadeOut = true }
        }
        // Let fade complete, then navigate (no slide animation)
        try? await Task.sleep(nanoseconds: 380_000_000)
        await MainActor.run {
            router.replace(with: .completion(lessonId: lessonId))
        }
    }

    @MainActor
    private func animate(_ duration: Double, _ curve: AnimCurve, changes: @escaping () -> Void) async {
        withAnimation(curve.swiftUI(duration)) { changes() }
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    // MARK: - Confetti

    private var confettiCanvas: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let elapsed = max(0, ctx.date.timeIntervalSince(startDate))
                Canvas { context, size in
                    drawConfetti(context: context, size: size, elapsed: elapsed)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Deterministic time-based confetti — 80 particles, no @State mutation per frame.
    private func drawConfetti(context: GraphicsContext, size: CGSize, elapsed: Double) {
        guard elapsed < 6.0 else { return }
        let palette: [Color] = [.brandDarkBlue, .brandLightBlue, .brandElectric]
        for i in 0..<80 {
            let fi = Double(i)
            // Deterministic seed values from particle index
            let seedX     = fract(sin(fi * 127.1) * 43758.5453)
            let seedDelay = fract(sin(fi * 311.7) * 53742.1234)
            let seedDrift = fract(sin(fi * 451.3) * 83413.5912) * 2.0 - 1.0
            let seedVel   = fract(sin(fi * 673.9) * 12345.6789) * 0.5 + 0.5
            let seedRot   = fract(sin(fi * 893.2) * 97531.2468)

            // Particles spawn staggered over the first 1.5s
            let localT = elapsed - seedDelay * 1.5
            guard localT > 0 else { continue }

            let yPos = -20.0 + localT * 180.0 * seedVel
            guard yPos < size.height + 20 else { continue }

            let xPos = seedX * size.width
                + seedDrift * 18.0 * sin(localT * (0.7 + seedDelay * 0.6) * 2.0 * .pi)

            // Fade out near bottom
            let fadeStart = size.height * 0.75
            let alpha = yPos < fadeStart
                ? 1.0
                : max(0, 1.0 - (yPos - fadeStart) / (size.height * 0.25))
            guard alpha > 0 else { continue }

            let rotation = localT * (1.5 + seedRot * 2.5) * 2.0 * .pi
            let pw = 6.0 + seedRot * 4.0  // 6–10 pts wide

            var ctx2 = context
            ctx2.opacity = alpha
            ctx2.translateBy(x: xPos, y: yPos)
            ctx2.rotate(by: .radians(rotation))
            ctx2.fill(
                Path(CGRect(x: -pw / 2, y: -pw * 0.2, width: pw, height: pw * 0.4)),
                with: .color(palette[i % palette.count])
            )
        }
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }
}

// MARK: - Animation curve helper

private enum AnimCurve {
    case easeOut, easeIn, linear

    func swiftUI(_ duration: Double) -> SwiftUI.Animation {
        switch self {
        case .easeOut: return .easeOut(duration: duration)
        case .linear:  return .linear(duration: duration)
        case .easeIn:  return .easeIn(duration: duration)
        }
    }
}
