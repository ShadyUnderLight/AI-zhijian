import SwiftUI

struct VariablePanelView: View {
    let variables: [UpstreamVariable]
    let onInsert: (UpstreamVariable) -> Void

    private var connectedVars: [UpstreamVariable] {
        variables.filter(\.isConnected)
    }

    private var availableVars: [UpstreamVariable] {
        variables.filter { !$0.isConnected }
    }

    private func grouped(_ items: [UpstreamVariable]) -> [(key: String, display: String, items: [UpstreamVariable])] {
        let dict = Dictionary(grouping: items, by: \.nodeId)
        return dict.keys.sorted { aId, bId in
            let aTitle = items.first(where: { $0.nodeId == aId })?.nodeTitle ?? aId
            let bTitle = items.first(where: { $0.nodeId == bId })?.nodeTitle ?? bId
            return aTitle.localizedCompare(bTitle) == .orderedAscending
        }.map { nid in
            let title = items.first(where: { $0.nodeId == nid })?.nodeTitle ?? nid
            return (nid, title, dict[nid]!.sorted { $0.portName < $1.portName })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !connectedVars.isEmpty {
                sectionHeader("已连接变量 (\(connectedVars.count))")
                ForEach(grouped(connectedVars), id: \.key) { group in
                    disclosureGroup(title: group.display, items: group.items, connected: true)
                }
            }

            if !availableVars.isEmpty {
                sectionHeader("可连接变量 (\(availableVars.count))")
                ForEach(grouped(availableVars), id: \.key) { group in
                    disclosureGroup(title: group.display, items: group.items, connected: false)
                }
            }

            if variables.isEmpty {
                Text("暂无可变量")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.top, 2)
    }

    @ViewBuilder
    private func disclosureGroup(title: String, items: [UpstreamVariable], connected: Bool) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { variable in
                    variableRow(variable, connected: connected)
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

    @ViewBuilder
    private func variableRow(_ variable: UpstreamVariable, connected: Bool) -> some View {
        let displayName = variable.variableName ?? variable.portName

        HStack(spacing: 6) {
            Image(systemName: connected ? "circle.fill" : "circle")
                .font(.system(size: 6))
                .foregroundColor(connected ? .green : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.caption)
                    .foregroundColor(connected ? .primary : .secondary)
                if let varName = variable.variableName, varName != variable.portName {
                    Text("来源: \(variable.portName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(variable.portType.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)

            Spacer()

            if connected {
                Text("已连接")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("待连接")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            if connected {
                onInsert(variable)
            }
        }
    }
}
