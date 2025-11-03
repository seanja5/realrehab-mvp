//
//  PracticeSensorSimulator.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//
import Foundation
import Combine

/// Emits ~50 Hz fake samples: knee waves up/down, small hip drift, flex rises near peak.
final class PracticeSensorSimulator {
    private let interval: TimeInterval = 1.0 / 50.0
    private var timer: AnyCancellable?
    private var t: Double = 0
    private let subject = PassthroughSubject<SensorSample, Never>()
    var publisher: AnyPublisher<SensorSample, Never> { subject.eraseToAnyPublisher() }

    func start() {
        stop(); t = 0
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                t += interval

                // Knee angle oscillates 0–180 with a ~0.5 Hz wave, add noise.
                let base = (sin(2 * .pi * 0.5 * t) * 0.5 + 0.5) * 180.0
                let knee = max(0, min(180, base + Double.random(in: -2...2)))

                // Hip drift stays small with occasional variation.
                let hip = abs(sin(t * 0.9)) * 6 + Double.random(in: -1...1)

                // Flex increases near the top of the wave (simulating quad activation).
                let flex = max(0, min(1, (sin(2 * .pi * 0.5 * t - .pi/8) * 0.5 + 0.5)
                                         + Double.random(in: -0.05...0.05)))

                self.subject.send(SensorSample(kneeAngleDeg: knee,
                                               hipDriftDeg: max(0, hip),
                                               flexActivation: flex))
            }
    }

    func stop() { timer?.cancel(); timer = nil }
}
