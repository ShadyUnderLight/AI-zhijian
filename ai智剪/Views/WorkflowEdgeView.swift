import SwiftUI

// MARK: - Edge Connection Points

struct EdgeConnectionPoints {
    let source: CGPoint
    let target: CGPoint
}

// MARK: - Workflow Edge View

struct WorkflowEdgeView: View {
    let edge: WorkflowEdge
    let sourcePoint: CGPoint
    let targetPoint: CGPoint
    let portType: WorkflowPortType
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        Path { path in
            path.move(to: sourcePoint)
            let controlOffset = max(80, abs(targetPoint.x - sourcePoint.x) * 0.4)
            path.addCurve(
                to: targetPoint,
                control1: CGPoint(x: sourcePoint.x + controlOffset, y: sourcePoint.y),
                control2: CGPoint(x: targetPoint.x - controlOffset, y: targetPoint.y)
            )
        }
        .stroke(edgeColor, style: StrokeStyle(
            lineWidth: isActive ? 3 : 2,
            lineCap: .round
        ))
        .shadow(color: isActive ? edgeColor.opacity(0.5) : .clear, radius: 4)
        .overlay(selectionOverlay)
    }

    // MARK: - Edge Color

    private var edgeColor: Color {
        if isSelected {
            return .accentColor
        }
        switch portType {
        case .text: return .blue
        case .image: return .orange
        case .video: return .pink
        case .file: return .gray
        case .json: return .purple
        case .any: return .secondary
        }
    }

    // MARK: - Selection Overlay

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            Path { path in
                path.move(to: sourcePoint)
                let controlOffset = max(80, abs(targetPoint.x - sourcePoint.x) * 0.4)
                path.addCurve(
                    to: targetPoint,
                    control1: CGPoint(x: sourcePoint.x + controlOffset, y: sourcePoint.y),
                    control2: CGPoint(x: targetPoint.x - controlOffset, y: targetPoint.y)
                )
            }
            .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(
                lineWidth: 8,
                lineCap: .round
            ))
        }
    }
}

// MARK: - Temporary Edge (during drag)

struct TemporaryEdgeView: View {
    let sourcePoint: CGPoint
    let currentPoint: CGPoint
    let portType: WorkflowPortType

    var body: some View {
        Path { path in
            path.move(to: sourcePoint)
            let controlOffset = max(80, abs(currentPoint.x - sourcePoint.x) * 0.4)
            path.addCurve(
                to: currentPoint,
                control1: CGPoint(x: sourcePoint.x + controlOffset, y: sourcePoint.y),
                control2: CGPoint(x: currentPoint.x - controlOffset, y: currentPoint.y)
            )
        }
        .stroke(edgeColor, style: StrokeStyle(
            lineWidth: 2,
            lineCap: .round,
            dash: [6, 4]
        ))
        .allowsHitTesting(false)
    }

    private var edgeColor: Color {
        switch portType {
        case .text: return .blue
        case .image: return .orange
        case .video: return .pink
        case .file: return .gray
        case .json: return .purple
        case .any: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        WorkflowEdgeView(
            edge: WorkflowEdge(
                sourceNodeId: "1",
                sourcePortId: "p1",
                targetNodeId: "2",
                targetPortId: "p2"
            ),
            sourcePoint: CGPoint(x: 50, y: 100),
            targetPoint: CGPoint(x: 250, y: 100),
            portType: .text,
            isActive: false,
            isSelected: false
        )

        TemporaryEdgeView(
            sourcePoint: CGPoint(x: 50, y: 200),
            currentPoint: CGPoint(x: 200, y: 250),
            portType: .image
        )
    }
    .frame(width: 300, height: 300)
    .padding()
}
