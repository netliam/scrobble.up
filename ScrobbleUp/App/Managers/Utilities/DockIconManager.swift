//
//  DockIconManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/29/25.
//

import AppKit
import Defaults

final class DockIconManager {
  static let shared = DockIconManager()

  private let defaultIcon: NSImage?
  private var currentArtwork: NSImage?

  private init() {
    defaultIcon = NSApp.applicationIconImage
  }

  func updateDockIcon(with artwork: NSImage?) {
    guard Defaults[.showArtworkInDock] else {
      resetToDefaultIcon()
      return
    }

    DispatchQueue.main.async {
      if let artwork = artwork {
        let styledArtwork = self.styleArtwork(artwork)
        NSApp.applicationIconImage = styledArtwork
        self.currentArtwork = styledArtwork
      } else {
        NSApp.applicationIconImage = self.defaultIcon
        self.currentArtwork = nil
      }
    }
  }
  func resetToDefaultIcon() {
    NSApp.applicationIconImage = defaultIcon
    currentArtwork = nil
  }

  private func styleArtwork(_ image: NSImage) -> NSImage {
    let size = NSSize(width: 512, height: 512)
    let styledImage = NSImage(size: size)

    styledImage.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let cornerRadius: CGFloat = size.width * 0.2

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -2)
    shadow.shadowBlurRadius = 4

    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()

    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.black.setFill()
    path.fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    path.addClip()
    image.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)

    styledImage.unlockFocus()

    return styledImage
  }
}
