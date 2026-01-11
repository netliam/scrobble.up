//
//  AppleScriptHelper.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/27/25.
//
//  Code borrowed from boring.notch
//  https://github.com/TheBoredTeam/boring.notch
//

import Foundation

class AppleScriptHelper {
	@discardableResult
	class func execute(_ scriptText: String) async throws -> NSAppleEventDescriptor? {
		try await withCheckedThrowingContinuation { continuation in
			Task.detached(priority: .userInitiated) {
				let script = NSAppleScript(source: scriptText)
				var error: NSDictionary?
				if let descriptor = script?.executeAndReturnError(&error) {
					continuation.resume(returning: descriptor)
				} else if let error = error {
					continuation.resume(
						throwing: NSError(
							domain: "AppleScriptError", code: 1, userInfo: error as? [String: Any]))
				} else {
					continuation.resume(
						throwing: NSError(
							domain: "AppleScriptError", code: 1,
							userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
				}
			}
		}
	}

	class func executeVoid(_ scriptText: String) async throws {
		_ = try await execute(scriptText)
	}
}
