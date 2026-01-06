//
//  TopAlbumsGridView.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import Cocoa

class TopAlbumsGridView: NSView {

	private let fixedWidth: CGFloat
	private let columns = 3
	private let rows = 3
	private let spacing: CGFloat = 8
	private let horizontalInset: CGFloat = 15
	private let verticalInset: CGFloat = 8

	private var albumViews: [AlbumArtworkView] = []
	private var albumViewConstraints: [NSLayoutConstraint] = []

	// MARK: - Initializers

	init(width: CGFloat) {
		self.fixedWidth = width
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		wantsLayer = true
		setupAlbumViews()
	}

	required init?(coder: NSCoder) {
		return nil
	}

	// MARK: - Setup

	private func setupAlbumViews() {
		let totalItems = columns * rows

		for _ in 0..<totalItems {
			let albumView = AlbumArtworkView(size: 80)
			albumView.translatesAutoresizingMaskIntoConstraints = false
			addSubview(albumView)
			albumViews.append(albumView)
		}
	}
	
	private func layoutAlbumViews() {
		NSLayoutConstraint.deactivate(albumViewConstraints)
		albumViewConstraints.removeAll()

		let availableWidth = bounds.width - (2 * horizontalInset)
		let totalSpacing = spacing * CGFloat(columns - 1)
		let imageSize = (availableWidth - totalSpacing) / CGFloat(columns)

		for (index, albumView) in albumViews.enumerated() {
			let row = index / columns
			let col = index % columns

			let xOffset = horizontalInset + (imageSize + spacing) * CGFloat(col)
			let yOffset = verticalInset + (imageSize + spacing) * CGFloat(row)

			let constraints = [
				albumView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
				albumView.topAnchor.constraint(equalTo: topAnchor, constant: yOffset),
				albumView.widthAnchor.constraint(equalToConstant: imageSize),
				albumView.heightAnchor.constraint(equalToConstant: imageSize),
			]

			albumViewConstraints.append(contentsOf: constraints)
		}

		NSLayoutConstraint.activate(albumViewConstraints)
	}

	// MARK: - Public Methods

	func configure(albums: [AlbumData]) {
		for (index, albumView) in albumViews.enumerated() {
			if index < albums.count {
				let album = albums[index]
				albumView.configure(
					artworkURL: album.artworkURL,
					title: album.title,
					artist: album.artist,
					playCount: album.playCount,
					action: album.action
				)
			} else {
				albumView.reset()
			}
		}
	}

	func reset() {
		for albumView in albumViews {
			albumView.reset()
		}
	}

	// MARK: - Overrides
	
	override func layout() {
		super.layout()
		layoutAlbumViews()
	}

	override var intrinsicContentSize: NSSize {
		guard bounds.width > 0 else {
			return NSSize(width: fixedWidth, height: 280)
		}
		
		let availableWidth = bounds.width - (2 * horizontalInset)
		let totalSpacing = spacing * CGFloat(columns - 1)
		let imageSize = (availableWidth - totalSpacing) / CGFloat(columns)
		let totalHeight = (imageSize * CGFloat(rows)) + (spacing * CGFloat(rows - 1)) + (2 * verticalInset)
		
		return NSSize(width: fixedWidth, height: totalHeight)
	}
}

// MARK: - Album Data Model

struct AlbumData {
	let artworkURL: URL?
	let title: String
	let artist: String
	let playCount: String
	let action: (() -> Void)?
}

// MARK: - Album Artwork View

class AlbumArtworkView: NSView {

	private var clickAction: (() -> Void)?
	private var albumTitle: String?
	private var albumArtist: String?

	private var isHovered: Bool = false {
		didSet {
			updateHoverState()
		}
	}
	private var trackingAreaRef: NSTrackingArea?
	private var hoverPopover: NSPopover?

	private let imageView: NSImageView = {
		let iv = NSImageView()
		iv.translatesAutoresizingMaskIntoConstraints = false
		iv.wantsLayer = true
		iv.imageScaling = .scaleProportionallyUpOrDown
		return iv
	}()

	private let overlayView: NSVisualEffectView = {
		let view = NSVisualEffectView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.material = .hudWindow
		view.state = .active
		view.wantsLayer = true
		view.alphaValue = 0
		return view
	}()

	private let placeholderView: NSView = {
		let view = NSView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
		return view
	}()

	// MARK: - Initializers

	init(size: CGFloat) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		wantsLayer = true
		setupViews()
		setupTrackingArea()
	}

	required init?(coder: NSCoder) {
		return nil
	}

	// MARK: - Setup

	private func setupViews() {
		addSubview(placeholderView)
		addSubview(imageView)
		addSubview(overlayView)

		NSLayoutConstraint.activate([
			placeholderView.leadingAnchor.constraint(equalTo: leadingAnchor),
			placeholderView.trailingAnchor.constraint(equalTo: trailingAnchor),
			placeholderView.topAnchor.constraint(equalTo: topAnchor),
			placeholderView.bottomAnchor.constraint(equalTo: bottomAnchor),

			imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
			imageView.topAnchor.constraint(equalTo: topAnchor),
			imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

			overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
			overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
			overlayView.topAnchor.constraint(equalTo: topAnchor),
			overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])

		placeholderView.isHidden = false
		imageView.isHidden = true
	}
	
	private func updateCornerRadius() {
		let cornerRadius = bounds.width * 0.05
		imageView.layer?.cornerRadius = cornerRadius
		imageView.layer?.masksToBounds = true
		overlayView.layer?.cornerRadius = cornerRadius
		placeholderView.layer?.cornerRadius = cornerRadius
		
		imageView.layer?.borderWidth = max(0.5, bounds.width * 0.00625)
		imageView.layer?.borderColor = NSColor.separatorColor.cgColor
	}

	private func setupTrackingArea() {
		if let ta = trackingAreaRef { removeTrackingArea(ta) }
		let options: NSTrackingArea.Options = [
			.mouseEnteredAndExited, .activeAlways, .inVisibleRect,
		]
		let ta = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
		addTrackingArea(ta)
		trackingAreaRef = ta
	}

	private func updateHoverState() {
		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.15
			overlayView.animator().alphaValue = isHovered ? 0.3 : 0
		}
		
		if isHovered {
			showPopover()
		} else {
			hidePopover()
		}
	}
	
	private func showPopover() {
		guard let title = albumTitle, let artist = albumArtist else { return }
		
		// Create popover content
		let label = NSTextField(labelWithString: "\(title)\n\(artist)")
		label.font = .systemFont(ofSize: 11)
		label.textColor = .labelColor
		label.alignment = .center
		label.maximumNumberOfLines = 2
		label.lineBreakMode = .byTruncatingTail
		
		let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
		label.frame = contentView.bounds.insetBy(dx: 8, dy: 8)
		label.autoresizingMask = [.width, .height]
		contentView.addSubview(label)
		
		let contentVC = NSViewController()
		contentVC.view = contentView
		
		// Create and show popover
		let popover = NSPopover()
		popover.contentViewController = contentVC
		popover.behavior = .transient
		popover.animates = true
		
		popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
		hoverPopover = popover
	}
	
	private func hidePopover() {
		hoverPopover?.close()
		hoverPopover = nil
	}

	// MARK: - Public Methods

	func configure(
		artworkURL: URL?, title: String, artist: String, playCount: String, action: (() -> Void)?
	) {
		self.clickAction = action
		self.albumTitle = title
		self.albumArtist = artist
		self.toolTip = "\(title)\n\(artist)\n\(playCount)"

		if let url = artworkURL {
			loadImage(from: url)
		} else {
			placeholderView.isHidden = false
			imageView.isHidden = true
		}
	}

	func reset() {
		imageView.image = nil
		imageView.isHidden = true
		placeholderView.isHidden = false
		clickAction = nil
		albumTitle = nil
		albumArtist = nil
		toolTip = nil
		hidePopover()
	}

	private func loadImage(from url: URL) {
		Task {
			do {
				let (data, _) = try await URLSession.shared.data(from: url)
				if let image = NSImage(data: data) {
					await MainActor.run {
						self.imageView.image = image
						self.imageView.isHidden = false
						self.placeholderView.isHidden = true
					}
				}
			} catch {
				print("Failed to load album artwork: \(error)")
			}
		}
	}

	// MARK: - Overrides
	
	override func layout() {
		super.layout()
		updateCornerRadius()
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		setupTrackingArea()
	}

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		super.viewWillMove(toWindow: newWindow)
		if newWindow == nil {
			isHovered = false
			hidePopover()
		}
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		updateTrackingAreas()
		updateCornerRadius()
	}

	override func mouseEntered(with event: NSEvent) {
		super.mouseEntered(with: event)
		isHovered = true
	}

	override func mouseExited(with event: NSEvent) {
		super.mouseExited(with: event)
		isHovered = false
	}

	override func mouseDown(with event: NSEvent) {
		super.mouseDown(with: event)
		clickAction?()
		NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
	}
}
