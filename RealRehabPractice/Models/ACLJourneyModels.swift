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
    
    static func layoutNodesZigZag(nodes: inout [LessonNode]) {
        for index in nodes.indices {
            nodes[index].yOffset = CGFloat(index) * 120
        }
    }
}
