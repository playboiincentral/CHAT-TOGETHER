import Foundation
import PhotosUI

// MARK: - Onboarding ViewModel
class OnboardingViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var gender: Gender? = nil
    @Published var avatar: UIImage? = nil
    @Published var bio: String = ""
    
    @Published var currentPage: Int = 0
    @Published var isLoading: Bool = false
}

// MARK: - Onboarding View
