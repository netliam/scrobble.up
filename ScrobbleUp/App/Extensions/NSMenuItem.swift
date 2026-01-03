//
//  NSMenu.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/2/26.
//

import AppKit

extension NSMenuItem {
	func truncateTitle(maxWidth: CGFloat) {
		let font = NSFont.menuFont(ofSize: 0)
		let attributes: [NSAttributedString.Key: Any] = [.font: font]
		let titleSize = (self.title as NSString).size(withAttributes: attributes)

		guard titleSize.width > maxWidth else { return }

		var testTitle = self.title
		while testTitle.count > 0 {
			let test = testTitle + "..."
			let size = (test as NSString).size(withAttributes: attributes)
			if size.width <= maxWidth {
				self.title = test
				return
			}
			testTitle = String(testTitle.dropLast())
		}
		self.title = "..."
	}
}
