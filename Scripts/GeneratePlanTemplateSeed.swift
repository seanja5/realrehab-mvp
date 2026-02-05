#!/usr/bin/env swift
import Foundation

// Replicates ACLJourneyModels.defaultACLPlanNodes() structure for seed generation
struct PlanNodeDTO: Codable {
    let id: String
    let title: String
    let icon: String
    let isLocked: Bool
    let reps: Int
    let restSec: Int
    let nodeType: String
    let phase: Int
}

let phases: [(exercises: [String], midBenchmark: String, endBenchmark: String, lessonCount: Int)] = [
    (["Seated Knee Extensions", "Quad Sets (Isometric)", "Heel Slides (Towel Slide)", "Ankle Pumps", "Calf Stretch (Seated Towel Stretch)"],
     "Straight Leg Raise Control (no knee lag)", "Full Extension (0° or matches other side)", 20),
    (["Terminal Knee Extensions", "Sit-to-Stand Squats", "Wall Sit (Shallow)", "Standing Calf Raises", "Seated Hamstring Stretch"],
     "Quad Confidence ≥ 7/10", "Wall Sit 10s (no shaking or pain)", 40),
    (["Step-Ups", "Single-Leg Sit-to-Stand", "Reverse Lunges", "Single-Leg Balance Hold", "Wall Sit (Deeper)"],
     "Step-Down Control (no knee collapse)", "Strength Symmetry ≥ 70%", 60),
    (["Split Squats", "Walking Lunges", "Lateral Step-Out Squats", "Single-Leg Wall Sit", "Tempo Squats (3s eccentric)"],
     "Fatigue Control (form maintained full set)", "Confidence Check (no hesitation/fear self-report)", 80)
]

var nodes: [PlanNodeDTO] = []
for (phaseIndex, phaseData) in phases.enumerated() {
    let phase = phaseIndex + 1
    let lessonCount = phaseData.lessonCount
    let midIndex = lessonCount / 2
    var lessonIndex = 0
    for i in 0..<(lessonCount + 2) {
        let id = UUID().uuidString
        if i == midIndex {
            nodes.append(PlanNodeDTO(id: id, title: phaseData.midBenchmark, icon: "video", isLocked: false, reps: 0, restSec: 0, nodeType: "benchmark", phase: phase))
        } else if i == lessonCount + 1 {
            nodes.append(PlanNodeDTO(id: id, title: phaseData.endBenchmark, icon: "video", isLocked: false, reps: 0, restSec: 0, nodeType: "benchmark", phase: phase))
        } else {
            let ex = phaseData.exercises[lessonIndex % phaseData.exercises.count]
            nodes.append(PlanNodeDTO(id: id, title: ex, icon: "video", isLocked: false, reps: 12, restSec: 3, nodeType: "lesson", phase: phase))
            lessonIndex += 1
        }
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let data = try encoder.encode(nodes)
let json = String(data: data, encoding: .utf8)!
print(json)
