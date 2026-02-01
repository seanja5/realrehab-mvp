//
//  ACLJourneyModels.swift
//  RealRehabPractice
//
//  ACL Tear Recovery Map – 4-phase content, node types, and default plan.
//

import SwiftUI

// MARK: - Node Type
public enum JourneyNodeType: String, Codable {
    case lesson
    case benchmark
}

// MARK: - ACL Phase (1–4)
public enum ACLPhase: Int, CaseIterable {
    case one = 1, two, three, four
    
    public var timeline: String {
        switch self {
        case .one: return "0–2 weeks"
        case .two: return "2–6 weeks"
        case .three: return "6–12 weeks"
        case .four: return "3–6+ months"
        }
    }
    
    public var goals: [String] {
        switch self {
        case .one:
            return [
                "Quad activation",
                "Restore extension",
                "Minimize swelling",
                "Build early confidence"
            ]
        case .two:
            return [
                "Increase knee range of motion",
                "Improve quad activation and confidence",
                "Begin controlled weight bearing",
                "Improve basic squat and sit-to-stand mechanics"
            ]
        case .three:
            return [
                "Build single-leg strength",
                "Improve knee stability and control",
                "Reduce knee collapse during movement",
                "Prepare for higher-demand functional tasks"
            ]
        case .four:
            return [
                "Improve dynamic movement control",
                "Build muscular endurance under load",
                "Increase confidence during complex movements",
                "Prepare for return to running, jumping, and sport-specific activity"
            ]
        }
    }
    
    public var exercises: [String] {
        switch self {
        case .one:
            return [
                "Seated Knee Extensions",
                "Quad Sets (Isometric)",
                "Heel Slides (Towel Slide)",
                "Ankle Pumps",
                "Calf Stretch (Seated Towel Stretch)"
            ]
        case .two:
            return [
                "Terminal Knee Extensions",
                "Sit-to-Stand Squats",
                "Wall Sit (Shallow)",
                "Standing Calf Raises",
                "Seated Hamstring Stretch"
            ]
        case .three:
            return [
                "Step-Ups",
                "Single-Leg Sit-to-Stand",
                "Reverse Lunges",
                "Single-Leg Balance Hold",
                "Wall Sit (Deeper)"
            ]
        case .four:
            return [
                "Split Squats",
                "Walking Lunges",
                "Lateral Step-Out Squats",
                "Single-Leg Wall Sit",
                "Tempo Squats (3s eccentric)"
            ]
        }
    }
    
    public var midBenchmarkTitle: String {
        switch self {
        case .one: return "Straight Leg Raise Control (no knee lag)"
        case .two: return "Quad Confidence ≥ 7/10"
        case .three: return "Step-Down Control (no knee collapse)"
        case .four: return "Fatigue Control (form maintained full set)"
        }
    }
    
    public var endBenchmarkTitle: String {
        switch self {
        case .one: return "Full Extension (0° or matches other side)"
        case .two: return "Wall Sit 10s (no shaking or pain)"
        case .three: return "Strength Symmetry ≥ 70%"
        case .four: return "Confidence Check (no hesitation/fear self-report)"
        }
    }
    
    public static func phase(from raw: Int) -> ACLPhase {
        ACLPhase(rawValue: max(1, min(4, raw))) ?? .one
    }
}

// MARK: - Lesson Node Model (shared between PT and Patient)
struct LessonNode: Identifiable {
    let id = UUID()
    var title: String
    var icon: IconType
    var isLocked: Bool
    var reps: Int
    var restSec: Int
    var yOffset: CGFloat = 0
    var nodeType: JourneyNodeType
    var phase: Int
    
    var sets: Int? = nil
    var restBetweenSets: Int? = nil
    var kneeBendAngle: Int? = nil
    var timeHoldingPosition: Int? = nil
    
    var enableReps: Bool = true
    var enableRestBetweenReps: Bool = true
    var enableSets: Bool = false
    var enableRestBetweenSets: Bool = false
    var enableKneeBendAngle: Bool = false
    var enableTimeHoldingPosition: Bool = false
    
    enum IconType {
        case person
        case video
        
        var systemName: String {
            switch self {
            case .person: return "figure.stand"
            case .video: return "video.fill"
            }
        }
    }
    
    init(
        title: String,
        icon: IconType = .video,
        isLocked: Bool = false,
        reps: Int = 12,
        restSec: Int = 3,
        nodeType: JourneyNodeType = .lesson,
        phase: Int = 1
    ) {
        self.title = title
        self.icon = icon
        self.isLocked = isLocked
        self.reps = reps
        self.restSec = restSec
        self.nodeType = nodeType
        self.phase = phase
    }
    
    static func lesson(title: String, icon: IconType = .video, isLocked: Bool = false, reps: Int = 12, restSec: Int = 3, phase: Int) -> LessonNode {
        var node = LessonNode(title: title, icon: icon, isLocked: isLocked, reps: reps, restSec: restSec, nodeType: .lesson, phase: phase)
        if node.title.lowercased().contains("wall sit") {
            node.enableReps = false
            node.enableRestBetweenReps = false
            node.enableSets = false
            node.enableRestBetweenSets = false
            node.enableKneeBendAngle = true
            node.enableTimeHoldingPosition = true
            node.kneeBendAngle = 120
            node.timeHoldingPosition = 30
        }
        return node
    }
    
    static func benchmark(title: String, phase: Int, isLocked: Bool = false) -> LessonNode {
        LessonNode(title: title, icon: .video, isLocked: isLocked, reps: 0, restSec: 0, nodeType: .benchmark, phase: phase)
    }
}

// MARK: - Lesson descriptions (one sentence per exercise)
extension ACLJourneyModels {
    /// Returns the one-sentence description for a lesson title, or nil for benchmarks/custom.
    static func lessonDescription(for title: String) -> String? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return lessonDescriptions[t] ?? lessonDescriptionsByPrefix.first { key, _ in
            t.lowercased().hasPrefix(key.lowercased()) || key.lowercased().hasPrefix(t.lowercased())
        }?.value
    }

    private static let lessonDescriptions: [String: String] = [
        // Phase 1
        "Seated Knee Extensions": "Slowly straighten your knee while seated, focusing on fully extending the leg and engaging your thigh muscle.",
        "Quad Sets (Isometric)": "Tighten your thigh muscle while keeping your leg straight, holding the contraction without moving the knee.",
        "Heel Slides (Towel Slide)": "Slide your heel toward your body while lying down to gently bend the knee and improve range of motion.",
        "Ankle Pumps": "Move your foot up and down to promote circulation and reduce swelling in the lower leg.",
        "Calf Stretch (Seated Towel Stretch)": "Use a towel to gently pull your foot toward you, stretching the calf while keeping the knee straight.",
        // Phase 2
        "Terminal Knee Extensions": "Straighten your knee from a slightly bent position to strengthen the quadriceps and improve knee control.",
        "Sit-to-Stand Squats (Chair Squats)": "Stand up from a chair and slowly sit back down while keeping your knees controlled and aligned.",
        "Sit-to-Stand Squats": "Stand up from a chair and slowly sit back down while keeping your knees controlled and aligned.",
        "Wall Sit (Shallow)": "Hold a gentle squat position against a wall to build early strength and endurance in the legs.",
        "Standing Calf Raises (Double-Leg)": "Lift your heels off the ground and slowly lower them to strengthen the calves and improve lower-leg stability.",
        "Standing Calf Raises": "Lift your heels off the ground and slowly lower them to strengthen the calves and improve lower-leg stability.",
        "Seated Hamstring Stretch": "Extend one leg and gently lean forward to stretch the muscles along the back of the thigh.",
        // Phase 3
        "Step-Ups": "Step onto a stair or elevated surface and slowly step back down, focusing on controlled knee movement.",
        "Single-Leg Sit-to-Stand": "Stand up from a chair using one leg, keeping the knee steady throughout the movement.",
        "Reverse Lunges (Short Step)": "Step backward into a lunge and return to standing, emphasizing balance and knee control.",
        "Reverse Lunges": "Step backward into a lunge and return to standing, emphasizing balance and knee control.",
        "Single-Leg Balance Hold": "Balance on one leg while maintaining a steady, controlled knee position.",
        "Wall Sit (Deeper)": "Hold a deeper squat against the wall to increase strength and endurance in the legs.",
        // Phase 4
        "Split Squats": "Lower into a squat with one foot forward and one foot back, focusing on control and stability in the front leg.",
        "Walking Lunges (Short Controlled Steps)": "Step forward into a lunge and continue walking while maintaining steady, controlled knee movement.",
        "Walking Lunges": "Step forward into a lunge and continue walking while maintaining steady, controlled knee movement.",
        "Lateral Step-Out Squats": "Step sideways into a squat and return to standing to strengthen the legs and improve side-to-side control.",
        "Single-Leg Wall Sit": "Hold a wall sit while lifting one foot off the ground to challenge single-leg strength and endurance.",
        "Tempo Squats (3-Second Lower)": "Lower into a squat slowly over three seconds to build strength, control, and movement awareness.",
        "Tempo Squats (3s eccentric)": "Lower into a squat slowly over three seconds to build strength, control, and movement awareness.",
    ]

    private static let lessonDescriptionsByPrefix: [(key: String, value: String)] = []
}

// MARK: - Default ACL Plan Generator
enum ACLJourneyModels {
    static var allExerciseNames: [String] {
        ACLPhase.allCases.flatMap { $0.exercises }
    }
    
    static var allExerciseNamesForPicker: [String] {
        allExerciseNames + ["Custom"]
    }
    
    static func defaultACLPlanNodes() -> [LessonNode] {
        var nodes: [LessonNode] = []
        
        for phaseCase in ACLPhase.allCases {
            let phase = phaseCase.rawValue
            let exercises = phaseCase.exercises
            let lessonCount: Int
            switch phaseCase {
            case .one: lessonCount = 20  // 5 × 4
            case .two: lessonCount = 40  // 5 × 8
            case .three: lessonCount = 60 // 5 × 12
            case .four: lessonCount = 80 // 5 × 16
            }
            
            let midIndex = lessonCount / 2
            var lessonIndex = 0
            
            for i in 0..<(lessonCount + 2) {
                if i == midIndex {
                    nodes.append(.benchmark(title: phaseCase.midBenchmarkTitle, phase: phase))
                } else if i == lessonCount + 1 {
                    nodes.append(.benchmark(title: phaseCase.endBenchmarkTitle, phase: phase))
                } else {
                    let ex = exercises[lessonIndex % exercises.count]
                    nodes.append(.lesson(title: ex, phase: phase))
                    lessonIndex += 1
                }
            }
        }
        
        layoutNodesZigZag(nodes: &nodes)
        return nodes
    }
    
    /// Vertical step between nodes within a phase (halved so bubbles are closer).
    static let baseStep: CGFloat = 60
    /// Vertical gap at each phase transition; same as baseStep so spacing is constant everywhere.
    static let phaseSeparatorClearance: CGFloat = 60
    
    /// Y offsets for each index with phase separator clearance; use for patient JourneyNode layout.
    static func layoutYOffsets(phases: [Int]) -> [CGFloat] {
        guard !phases.isEmpty else { return [] }
        var result: [CGFloat] = []
        var runningY: CGFloat = 0
        for index in phases.indices {
            if index > 0, phases[index] != phases[index - 1] {
                runningY += phaseSeparatorClearance
            }
            result.append(runningY)
            runningY += baseStep
        }
        return result
    }
    
    static func layoutNodesZigZag(nodes: inout [LessonNode]) {
        guard !nodes.isEmpty else { return }
        let phases = nodes.map(\.phase)
        let yOffsets = layoutYOffsets(phases: phases)
        for (index, y) in yOffsets.enumerated() where index < nodes.count {
            nodes[index].yOffset = y
        }
    }
    
    /// Total content height from last node yOffset (for frame height).
    static func contentHeight(lastNodeYOffset: CGFloat, nodeContentOffset: CGFloat = 40) -> CGFloat {
        lastNodeYOffset + nodeContentOffset + 60
    }

    /// Phase boundary Y positions in GeometryReader content space (node at yOffset + nodeContentOffset).
    /// Use for separator lines and phase anchors so they move when lessons are added/removed.
    /// - Parameters:
    ///   - nodes: (yOffset, phase) for each node (e.g. from layoutNodesZigZag).
    ///   - nodeContentOffset: Y offset of first node in content (e.g. 40).
    ///   - gapBelowLastNode: Gap between last node of phase and separator line (e.g. 60).
    ///   - maxHeight: Content height; boundaries are clamped and ordered.
    /// - Returns: (phase2Y, phase3Y, phase4Y) in content coordinates.
    static func phaseBoundaryYs(
        nodes: [(yOffset: CGFloat, phase: Int)],
        nodeContentOffset: CGFloat = 40,
        gapBelowLastNode: CGFloat? = nil,
        maxHeight: CGFloat
    ) -> (phase2: CGFloat, phase3: CGFloat, phase4: CGFloat) {
        let gap = gapBelowLastNode ?? (phaseSeparatorClearance / 2)
        let lastY = { (phase: Int) -> CGFloat in
            nodes.last(where: { $0.phase == phase })?.yOffset ?? 0
        }
        var p2 = lastY(1) + nodeContentOffset + gap
        var p3 = lastY(2) + nodeContentOffset + gap
        var p4 = lastY(3) + nodeContentOffset + gap
        p2 = min(max(p2, 0), maxHeight)
        p3 = min(max(p3, p2 + 1), maxHeight)
        p4 = min(max(p4, p3 + 1), maxHeight)
        return (p2, p3, p4)
    }
}
