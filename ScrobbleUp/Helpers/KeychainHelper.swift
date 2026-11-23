import Foundation
import Security

/// Stores secrets in the data protection keychain. Its items belong to the app's
/// application identifier (team + bundle ID), not to one signed binary, so app
/// updates don't trigger the "wants to access the keychain" prompt.
final class KeychainHelper {
	static let shared = KeychainHelper()
	private init() {}

	private func query(_ key: String, dataProtection: Bool = true) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: "ScrobbleUp",
			kSecAttrAccount as String: key,
			kSecUseDataProtectionKeychain as String: dataProtection,
		]
	}

	func set(_ value: String, for key: String) {
		SecItemDelete(query(key) as CFDictionary)

		var add = query(key)
		add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
		add[kSecValueData as String] = Data(value.utf8)
		SecItemAdd(add as CFDictionary, nil)
	}

	func get(_ key: String) -> String? {
		if let value = read(query(key)) { return value }

		// One-time move from the old file-based keychain. This read may prompt one last time.
		let legacy = query(key, dataProtection: false)
		guard let value = read(legacy) else { return nil }
		set(value, for: key)
		if read(query(key)) == value {  // only delete the old item once the copy is safe
			SecItemDelete(legacy as CFDictionary)
		}
		return value
	}

	func remove(_ key: String) {
		SecItemDelete(query(key) as CFDictionary)
	}

	private func read(_ base: [String: Any]) -> String? {
		var q = base
		q[kSecReturnData as String] = true
		q[kSecMatchLimit as String] = kSecMatchLimitOne

		var item: CFTypeRef?
		guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
			let data = item as? Data
		else { return nil }
		return String(data: data, encoding: .utf8)
	}
}
