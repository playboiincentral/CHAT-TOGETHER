import Foundation
import PhotosUI

// MARK: - Onboarding ViewModel
class OnboardingViewModel: ObservableObject {
    @Published var dobText: String = ""
    @Published var displayName: String = ""
    @Published var gender: Gender? = nil
    @Published var avatar: UIImage? = nil
    @Published var bio: String = ""
    
    @Published var currentPage: Int = 0
    @Published var isLoading: Bool = false
    
    func formatDOB(_ input: String) -> String {
        // 1. Lấy chỉ số (bỏ hết /)
        let digits = input.replacingOccurrences(of: "/", with: "")
        
        // 2. Giới hạn 8 số
        let trimmed = String(digits.prefix(8))
        
        var result = ""
        
        for (index, char) in trimmed.enumerated() {
            result.append(char)
            
            if index == 1 || index == 3 {
                result.append("/")
            }
        }
        
        return result
    }
    
    func isValidDOB(_ dob: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.isLenient = false
        
        guard let date = formatter.date(from: dob) else {
            return false
        }
        
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: date, to: Date()).year ?? 0
        
        return age >= 18 && age < 100
    }
    
    func ageFromDOBString(_ dob: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        
        guard let date = formatter.date(from: dob) else {
            return nil
        }
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
        
        return ageComponents.year
    }
}
