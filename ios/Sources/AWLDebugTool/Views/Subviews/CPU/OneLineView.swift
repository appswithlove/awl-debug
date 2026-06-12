//
//  OneLineView.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 12.06.2026.
//

import SwiftUI

struct OneLineView: View {
    let geo: GeometryProxy
    let values: [CGFloat]
    let maxValue: CGFloat
    let capacity: Int
    let color: Color
    let text: String?
    
    var body: some View {
        ZStack(alignment: .leading) {
            let maxValue = max(values.max() ?? 0, maxValue)
            Path { path in
                let stepX = geo.size.width / CGFloat(max(capacity - 1, 1))
                for (i, value) in values.enumerated() {
                    let point = CGPoint(
                        x: CGFloat(i) * stepX,
                        y: geo.size.height * (1 - CGFloat(value / maxValue))
                    )
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(color, lineWidth: 1)
            
            if let text {
                VStack(alignment: .leading) {
                    Text(String(format: "%.0f", maxValue) + text)
                    Spacer()
                    Text("0" + text)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}
