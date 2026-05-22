import Foundation

class EditTaskCoordinator: ObservableObject {
    @Published var editingItem: GenerationQueueItem?
    @Published var navigateToKind: GenerationJobKind?
    @Published var applyRecord: WorkRecord?
    @Published var prefillPrompt: PrefillPrompt?

    struct PrefillPrompt {
        let id = UUID()
        let text: String
        let kind: GenerationJobKind
        let sourceShotTitle: String
    }

    func consumePrefill(kind: GenerationJobKind) -> String? {
        guard let p = prefillPrompt, p.kind == kind else { return nil }
        prefillPrompt = nil
        return p.text
    }
}
