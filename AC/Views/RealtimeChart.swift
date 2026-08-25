//
//  RealtimeChart.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct RealtimeChartCard: View {
    let title: String
    let seriesCount: Int
    let colors: [Color]
    let interval: TimeInterval
    let fetch: () -> [Double]

    @State private var history: [[Double]] = []
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
            Sparkline(series: history, colors: colors, height: 40)
        }
        .padding(.vertical, 2)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        stop()
        history = Array(repeating: [], count: seriesCount)
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            self.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let values = fetch()
        guard values.count == seriesCount else { return }
        for i in values.indices {
            history[i].append(values[i])
            if history[i].count > 60 {
                history[i].removeFirst()
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct Sparkline: View {
    let series: [[Double]]
    let colors: [Color]
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(0..<series.count, id: \.self) { i in
                    let points = series[i]
                    if points.count > 1 {
                        Path { path in
                            let step = w / CGFloat(points.count - 1)
                            for j in points.indices {
                                let x = CGFloat(j) * step
                                let y = h - CGFloat(min(max(points[j], 0), 1)) * h
                                if j == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(colors[i % colors.count], style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
        .frame(height: height)
        .clipped()
    }
}
