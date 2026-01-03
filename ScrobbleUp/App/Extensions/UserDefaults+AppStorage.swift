//
//  UserDefaults.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/2/26.
//

import Combine
import Foundation
import SwiftUI

protocol UserDefaultsKeyProtocol {
	associatedtype Value
	var key: String { get }
	var defaultValue: Value { get }
}

struct UserDefaultsKey<T>: UserDefaultsKeyProtocol {
	typealias Value = T

	let key: String
	let defaultValue: T

	init(_ key: String, defaultValue: T) {
		self.key = key
		self.defaultValue = defaultValue
	}
}

extension UserDefaults {

	// MARK: - Basic Get/Set

	func get<T>(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) -> T {
		let key = Keys.self[keyPath: keyPath]
		return object(forKey: key.key) as? T ?? key.defaultValue
	}

	func set<T>(_ value: T, for keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) {
		let key = Keys.self[keyPath: keyPath]
		set(value, forKey: key.key)
	}

	// MARK: - RawRepresentable (Enums)

	func get<T: RawRepresentable>(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) -> T {
		let key = Keys.self[keyPath: keyPath]
		guard let rawValue = object(forKey: key.key) as? T.RawValue,
			let value = T(rawValue: rawValue)
		else {
			return key.defaultValue
		}
		return value
	}

	func set<T: RawRepresentable>(_ value: T, for keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) {
		let key = Keys.self[keyPath: keyPath]
		set(value.rawValue, forKey: key.key)
	}

	// MARK: - Codable

	func getCodable<T: Codable>(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) -> T {
		let key = Keys.self[keyPath: keyPath]
		guard let data = data(forKey: key.key),
			let value = try? JSONDecoder().decode(T.self, from: data)
		else {
			return key.defaultValue
		}
		return value
	}

	func setCodable<T: Codable>(_ value: T, for keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) {
		let key = Keys.self[keyPath: keyPath]
		guard let data = try? JSONEncoder().encode(value) else { return }
		set(data, forKey: key.key)
	}

	// MARK: - Subscript Access

	subscript<T>(keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) -> T {
		get { get(keyPath) }
		set { set(newValue, for: keyPath) }
	}

	subscript<T: RawRepresentable>(keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) -> T {
		get { get(keyPath) }
		set { set(newValue, for: keyPath) }
	}

	// MARK: - Remove

	func remove<T>(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>) {
		let key = Keys.self[keyPath: keyPath]
		removeObject(forKey: key.key)
	}

	// MARK: - Observe

	func observe<T: Equatable>(
		_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>, onChange: @escaping (T) -> Void
	) -> AnyCancellable {
		let initialValue = get(keyPath)
		onChange(initialValue)

		return NotificationCenter.default
			.publisher(for: UserDefaults.didChangeNotification)
			.compactMap { [weak self] _ in
				self?.get(keyPath)
			}
			.removeDuplicates()
			.sink { onChange($0) }
	}

	func observe<T: RawRepresentable>(
		_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>, onChange: @escaping (T) -> Void
	) -> AnyCancellable where T.RawValue: Equatable {
		let initialValue = get(keyPath)
		onChange(initialValue)

		return NotificationCenter.default
			.publisher(for: UserDefaults.didChangeNotification)
			.compactMap { [weak self] _ in
				self?.get(keyPath)
			}
			.removeDuplicates(by: { $0.rawValue == $1.rawValue })
			.sink { onChange($0) }
	}
    
    func observe<T: RawRepresentable & Equatable>(
        _ keyPath: KeyPath<Keys.Type, UserDefaultsKey<T>>, onChange: @escaping (T) -> Void
    ) -> AnyCancellable where T.RawValue: Equatable {
        let initialValue: T = get(keyPath)
        onChange(initialValue)

        return NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .compactMap { [weak self] _ -> T? in
                self?.get(keyPath)
            }
            .removeDuplicates()
            .sink { onChange($0) }
    }
}

extension AppStorage {
	init(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<Value>>, store: UserDefaults = .standard)
	where Value == Bool {
		let key = Keys.self[keyPath: keyPath]
		self.init(wrappedValue: key.defaultValue, key.key, store: store)
	}

	init(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<Value>>, store: UserDefaults = .standard)
	where Value == Int {
		let key = Keys.self[keyPath: keyPath]
		self.init(wrappedValue: key.defaultValue, key.key, store: store)
	}

	init(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<Value>>, store: UserDefaults = .standard)
	where Value == String {
		let key = Keys.self[keyPath: keyPath]
		self.init(wrappedValue: key.defaultValue, key.key, store: store)
	}

	init(_ keyPath: KeyPath<Keys.Type, UserDefaultsKey<Value>>, store: UserDefaults = .standard)
	where Value: RawRepresentable, Value.RawValue == String {
		let key = Keys.self[keyPath: keyPath]
		self.init(wrappedValue: key.defaultValue, key.key, store: store)
	}
}
