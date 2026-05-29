//  CategoryDetector.swift
//  ClipSync
//
//  Created by Kiann Skkandann on 12/2/25.
//

import Foundation

enum ClipboardCategory: String {
    case url = "URL"
    case email = "Email"
    case phone = "Phone"
    case address = "Address"
    case image = "Image"
    case code = "Code"
    case number = "Number"
    case text = "Text"
    
    var icon: String {
        switch self {
        case .url: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .address: return "map.fill"
        case .image: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .number: return "number"
        case .text: return "doc.text"
        }
    }
    
    var color: String {
        switch self {
        case .url: return "blue"
        case .email: return "green"
        case .phone: return "orange"
        case .address: return "red"
        case .image: return "purple"
        case .code: return "purple"
        case .number: return "pink"
        case .text: return "gray"
        }
    }
}

class CategoryDetector {
    static func detectCategory(for text: String) -> ClipboardCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // URL detection (check first - most specific)
        if isURL(trimmed) {
            return .url
        }
        
        // Email detection
        if isEmail(trimmed) {
            return .email
        }
        
        // Address detection (check BEFORE phone - addresses can have numbers)
        if isAddress(trimmed) {
            return .address
        }
        
        // Phone detection (after address)
        if isPhone(trimmed) {
            return .phone
        }
        
        // Code detection (contains common code patterns)
        if isCode(trimmed) {
            return .code
        }
        
        // Number detection
        if isNumber(trimmed) {
            return .number
        }
        
        return .text
    }
    
    private static func isURL(_ text: String) -> Bool {
        let urlPattern = "^(https?://|www\\.)[^\\s]+\\.[a-z]{2,}(/[^\\s]*)?$"
        return text.range(of: urlPattern, options: .regularExpression, range: nil, locale: nil) != nil
    }
    
    private static func isEmail(_ text: String) -> Bool {
        let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return text.range(of: emailPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private static func isPhone(_ text: String) -> Bool {
        let digitsOnly = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        guard digitsOnly.count >= 10 && digitsOnly.count <= 15 else {
            return false
        }
        
        let hasPhoneFormatting = text.contains(where: { "()-+. ".contains($0) })
        
        let addressWords = ["street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd",
                           "lane", "ln", "drive", "dr", "court", "ct", "place", "pl", "way",
                           "hwy", "highway", "parkway", "pkwy", "#", "apt", "suite", "unit"]
        let lowercased = text.lowercased()
        let hasAddressWords = addressWords.contains { lowercased.contains($0) }
        
        if hasAddressWords {
            return false
        }
        
        if text.count > 30 {
            return false
        }
        
        return hasPhoneFormatting
    }
    
    private static func isAddress(_ text: String) -> Bool {
        let addressIndicators = [
            "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd",
            "lane", "ln", "drive", "dr", "court", "ct", "place", "pl", "way",
            "circle", "cir", "parkway", "pkwy", "highway", "hwy",
            "apt", "apartment", "suite", "unit", "floor", "building", "#"
        ]
        
        let lowercased = text.lowercased()
        let hasAddressIndicator = addressIndicators.contains { lowercased.contains($0) }
        
        if !hasAddressIndicator {
            return false
        }
        
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) else {
            return simpleAddressCheck(text)
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        
        if let match = matches.first,
           match.resultType == .address,
           match.range.length > text.count / 2 {
            return true
        }
        
        return simpleAddressCheck(text)
    }
    
    private static func simpleAddressCheck(_ text: String) -> Bool {
        let wordCount = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        let hasLeadingNumber = text.first?.isNumber ?? false
        let hasComma = text.contains(",")
        
        let addressIndicators = [
            "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd",
            "lane", "ln", "drive", "dr", "court", "ct", "place", "pl", "way",
            "hwy", "highway", "parkway", "pkwy", "#", "apt", "suite"
        ]
        
        let lowercased = text.lowercased()
        let hasAddressIndicator = addressIndicators.contains { lowercased.contains($0) }
        
        return hasAddressIndicator &&
               wordCount >= 3 &&
               (hasLeadingNumber || hasComma) &&
               text.count < 200
    }
    
    private static func isCode(_ text: String) -> Bool {
        let codeIndicators = [
            "func ", "function ", "def ", "class ", "import ", "const ",
            "let ", "var ", "if (", "for (", "while (", "{", "}", "=>",
            "public ", "private ", "return ", "<?php", "#!/"
        ]
        
        return codeIndicators.contains { text.contains($0) } ||
               (text.filter { $0 == "{" }.count > 2 && text.filter { $0 == "}" }.count > 2)
    }
    
    private static func isNumber(_ text: String) -> Bool {
        let numberPattern = "^-?\\d+(\\.\\d+)?$"
        return text.range(of: numberPattern, options: .regularExpression) != nil
    }
}
