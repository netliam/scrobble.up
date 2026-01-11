//
//  NSImage.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/28/25.
//

import AppKit

extension NSImage {
	func styled(
		size: NSSize? = nil,
		cornerRadius: CGFloat = 0,
		isCircle: Bool = false
	) -> NSImage {

		let targetSize = size ?? self.size
		let newImage = NSImage(size: targetSize)
		newImage.lockFocus()

		let rect = NSRect(origin: .zero, size: targetSize)

		let path: NSBezierPath
		if isCircle {
			path = NSBezierPath(ovalIn: rect)
		} else if cornerRadius > 0 {
			path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
		} else {
			path = NSBezierPath(rect: rect)
		}

		path.addClip()

		let context = NSGraphicsContext.current
		context?.imageInterpolation = .high

		self.draw(
			in: rect,
			from: NSRect(origin: .zero, size: self.size),
			operation: .copy,
			fraction: 1.0)

		newImage.unlockFocus()
		return newImage
	}

	func configureForMenu(size: CGFloat = 21, weight: NSFont.Weight = .regular) -> NSImage {
		let base = (self.copy() as? NSImage) ?? self
		let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
		return base.withSymbolConfiguration(config) ?? base
	}
}
