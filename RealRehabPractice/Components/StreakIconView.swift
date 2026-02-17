//
//  StreakIconView.swift
//  RealRehabPractice
//
//  Fire icon for streak on patient journey header. Red + number when streak 2+, gray when lost (24h), then hidden.
//

import SwiftUI

struct StreakIconView: View {
    let state: StreakState

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .active(let count):
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.red)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.red)
            }
        case .gray:
            Image(systemName: "flame.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.gray)
        }
    }
}
