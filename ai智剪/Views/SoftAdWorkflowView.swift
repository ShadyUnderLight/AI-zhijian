import SwiftUI

// MARK: - 软广工作流 View

struct SoftAdWorkflowView: View {
    @EnvironmentObject var api: APIService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("软广工作流")
                .font(.title2).bold()
            Text("此功能正在开发中，敬请期待。")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    SoftAdWorkflowView()
        .environmentObject(APIService.shared)
}
