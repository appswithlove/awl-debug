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
    let minValue: CGFloat?
    let capacity: Int
    let color: Color
    let labelSign: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            let minValue = floor(minValue ?? (values.min() ?? 0))
            let maxValue = ceil(max(values.max() ?? 0, minValue + 1))
            Path { path in
                let stepX = geo.size.width / CGFloat(max(capacity - 1, 1))
                for (i, value) in values.enumerated() {
                    let point = CGPoint(
                        x: CGFloat(i) * stepX,
                        y: geo.size.height * (1 - CGFloat((value - minValue) / (maxValue - minValue)))
                    )
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(color, lineWidth: 1)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(maxValue))" + labelSign)
                Spacer(minLength: 0)
                Text("\(Int(minValue))" + labelSign)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.primary)
            .opacity(0.5)
        }
    }
}
