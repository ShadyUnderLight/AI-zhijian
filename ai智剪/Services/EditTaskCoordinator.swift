import Foundation

class EditTaskCoordinator: ObservableObject {
    @Published var editingItem: GenerationQueueItem?
    @Published var navigateToKind: GenerationJobKind?
    @Published var applyRecord: WorkRecord?
    @Published var prefillPrompt: PrefillPrompt?

    struct PrefillPrompt {
        let text: String
        let kind: GenerationJobKind
        let sourceShotTitle: String
    }
}
