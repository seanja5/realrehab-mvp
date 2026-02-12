//
//  NPIVerificationService.swift
//  RealRehabPractice
//
//  Verifies PT NPI number and name against the CMS NPI Registry public API.
//

import Foundation

enum NPIVerificationService {
    private static let baseURL = "https://npiregistry.cms.hhs.gov/api/"
    
    /// Result of NPI lookup: verified (NPI exists and name matches), notVerified (NPI exists but name doesn't match or NPI not found), or error (network/parse failure).
    enum VerificationResult {
        case verified
        case notVerified
        case error
    }
    
    /// Verify that the given NPI number exists in the NPI Registry and that the registered name matches the given first and last name.
    /// - Returns: .verified if NPI found and name matches, .notVerified if NPI not found or name doesn't match, .error if request failed.
    static func verify(npi: String, firstName: String?, lastName: String?) async -> VerificationResult {
        let trimmedNPI = npi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNPI.isEmpty,
              trimmedNPI.count == 10,
              trimmedNPI.allSatisfy({ $0.isNumber }) else {
            return .notVerified
        }
        
        guard let url = URL(string: "\(baseURL)?number=\(trimmedNPI)&version=2.1") else {
            return .error
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .error
            }
            
            let decoded = try JSONDecoder().decode(NPIResponse.self, from: data)
            guard decoded.result_count >= 1,
                  let first = decoded.results.first,
                  let basic = first.basic else {
                return .notVerified
            }
            
            let registryFirst = (basic.first_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let registryLast = (basic.last_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let enteredFirst = (firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let enteredLast = (lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if registryFirst.isEmpty && registryLast.isEmpty {
                return .notVerified
            }
            // Normalize for comparison: exact match after lowercased trim
            let namesMatch = registryFirst == enteredFirst && registryLast == enteredLast
            
            return namesMatch ? .verified : .notVerified
        } catch {
            print("⚠️ NPIVerificationService: \(error)")
            return .error
        }
    }
    
    private struct NPIResponse: Decodable {
        let result_count: Int
        let results: [NPIResult]
    }
    
    private struct NPIResult: Decodable {
        let basic: NPIBasic?
    }
    
    private struct NPIBasic: Decodable {
        let first_name: String?
        let last_name: String?
        let credential: String?
    }
}
