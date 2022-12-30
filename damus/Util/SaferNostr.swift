//
//  SaferNostr.swift
//  damus
//
//  Created by Thomas Tastet on 30/12/2022.
//

import Foundation

struct SNRouteNIP05 {
    let nip05: String
}

struct SNRouteNIP05Response: Codable {
    let status: String
    let code: Int
    let pubkey: String?
    let updated_at: UInt64?
    
    static func parse(_ jsonString: String) -> SNRouteNIP05Response? {
        let decoder = JSONDecoder()
        
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let response = try decoder.decode(SNRouteNIP05Response.self, from: data)
            return response
        } catch {
            print(error)
            return nil
        }
    }
}

enum SNRoutes {
    case nip05(SNRouteNIP05)
}

enum SNPreparedFetchReturn {
    case nip05(SNRouteNIP05Response)
}

func SNPreparedFetch(type: SNRoutes) -> SNPreparedFetchReturn? {
    let safer_nostr_enabled: Bool = UserDefaults.standard.bool(forKey: "safer_nostr_enabled")
    let safer_nostr_url: String = UserDefaults.standard.string(forKey: "safer_nostr_url")!
    let safer_nostr_pass: String? = UserDefaults.standard.string(forKey: "safer_nostr_pass")
    
    if !safer_nostr_enabled {
        return nil
    }
    
    switch type {
    case .nip05(let params):
        let dictionary: [String: String] = ["nip05": params.nip05]
        let body = SNFetch(instance_url: safer_nostr_url, instance_password: safer_nostr_pass, variables: dictionary)
        
        guard let body = body else {
            return nil
        }
        
        guard let response = SNRouteNIP05Response.parse(body) else {
            return nil
        }
        
        return .nip05(response)
    }
}

func SNFetch(instance_url: String, instance_password: String?, variables: [String: String]) -> String? {
    var urlComponents = URLComponents(string: instance_url)!
    urlComponents.queryItems = [URLQueryItem]()

    for (key, value) in variables {
        urlComponents.queryItems?.append(URLQueryItem(name: key, value: value))
    }

    if let instance_password = instance_password {
        urlComponents.queryItems?.append(URLQueryItem(name: "pass", value: instance_password))
    }

    let url = urlComponents.url!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    var body: String?
    let semaphore = DispatchSemaphore(value: 0)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            body = String(data: data, encoding: .utf8)
        }
        semaphore.signal()
    }.resume()
    
    _ = semaphore.wait(timeout: .distantFuture)
    
    return body
}

struct SNCheckStatus: Codable {
    let status: String
    let code: Int
    
    static func parse(_ jsonString: String) -> SNCheckStatus? {
        let decoder = JSONDecoder()
        
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let response = try decoder.decode(SNCheckStatus.self, from: data)
            return response
        } catch {
            print(error)
            return nil
        }
    }
}

