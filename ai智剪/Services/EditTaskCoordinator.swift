import Foundation

class EditTaskCoordinator: ObservableObject {
    @Published var editingItem: GenerationQueueItem?
    @Published var navigateToKind: GenerationJobKind?
}
