import SwiftUI

struct VariablePanelView: View {
    let variables: [UpstreamVariable]
    let onInsert: (String) -> Void

    private var groupedVariables: [(key: String, items: [UpstreamVariable])] {
        Dictionary(grouping: variables, by: \.nodeTitle)
            .sorted { $0.key.localizedCompare($1.key) == .orderedAscending }
            .map { ($0.key, $0.value.sorted { $0.portName < $1.portName }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if variables.isEmpty {
                Text("暂无可变量")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(groupedVariables, id: \.key) { title, items in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(items) { variable in
                                variableRow(variable)
                            }
                        }
                        .padding(.leading, 8)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.fill.on.square")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("(\(items.count))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func variableRow(_ variable: UpstreamVariable) -> some View {
        HStack(spacing: 6) {
            Image(systemName: variable.isConnected ? "circle.fill" : "circle")
                .font(.system(size: 6))
                .foregroundColor(variable.isConnected ? .green : .secondary)

            Text(variable.portName)
                .font(.caption)
                .foregroundColor(variable.isConnected ? .primary : .secondary)

            Text(variable.portType.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)

            if variable.isConnected {
                Text("已连接")
                    .font(.caption2)
                    .foregroundColor(.green)
            }

            Spacer()

            Button {
                onInsert(variable.portName)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("插入 {{\(variable.portName)}}")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            onInsert(variable.portName)
        }
    }
}
