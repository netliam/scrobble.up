import Cocoa

class RecentlyPlayedMenuItemView: NSView {

	private let fixedWidth: CGFloat

	private let contentInsets = NSEdgeInsets(top: 6, left: 15, bottom: 6, right: 12)
	private var titleLeadingWithImage: NSLayoutConstraint?
	private var titleLeadingWithoutImage: NSLayoutConstraint?
	private var imageWidthConstraint: NSLayoutConstraint?
	private var imageHeightConstraint: NSLayoutConstraint?
	private var imageLeadingConstraint: NSLayoutConstraint?
	private var imageCenterYConstraint: NSLayoutConstraint?

	private var isHovered: Bool = false {
		didSet {
			selectionView.isHidden = !isHovered
			updateTextColorsForHover()
		}
	}
	private var trackingAreaRef: NSTrackingArea?

	private let hoverCornerRadius: CGFloat = 6

	private let selectionView: NSVisualEffectView = {
		let view = NSVisualEffectView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.material = .selection
        view.isEmphasized = true
		view.state = .active
		view.wantsLayer = true
		view.layer?.cornerRadius = 6
		view.isHidden = true
		return view
	}()

	private let imageView: NSImageView = {
		let iv = NSImageView()
		iv.translatesAutoresizingMaskIntoConstraints = false
		iv.wantsLayer = true
		iv.layer?.cornerRadius = 4
		iv.layer?.masksToBounds = true
		iv.imageScaling = .scaleProportionallyUpOrDown
		return iv
	}()

	private let titleLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = NSFont.systemFont(ofSize: 13)
		label.lineBreakMode = .byTruncatingTail
		label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		label.maximumNumberOfLines = 1
		return label
	}()

	private let subtitleLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = NSFont.systemFont(ofSize: 11)
		label.textColor = NSColor.secondaryLabelColor
		label.lineBreakMode = .byTruncatingTail
		label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		label.maximumNumberOfLines = 1
		return label
	}()

	public var image: NSImage? {
		didSet {
			imageView.image = image
			updateImageVisibility()
		}
	}

	public var title: String {
		get { titleLabel.stringValue }
		set { titleLabel.stringValue = newValue }
	}

	public var subtitle: String? {
		get { subtitleLabel.isHidden ? nil : subtitleLabel.stringValue }
		set {
			if let newSub = newValue, !newSub.isEmpty {
				subtitleLabel.stringValue = newSub
				subtitleLabel.isHidden = false
			} else {
				subtitleLabel.stringValue = ""
				subtitleLabel.isHidden = true
			}
		}
	}

	// MARK: - Initializers

	init(width: CGFloat) {
		self.fixedWidth = width
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		wantsLayer = true
		setupSubviews()
		setupConstraints()
		updateImageVisibility()
		setupTrackingArea()
	}

	required init?(coder: NSCoder) {
		return nil
	}

	// MARK: - Setup

	private func setupSubviews() {
		addSubview(selectionView)

		addSubview(imageView)
		addSubview(titleLabel)
		addSubview(subtitleLabel)

		titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
		subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
	}

	private func setupConstraints() {
		NSLayoutConstraint.activate([
			selectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
			selectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
			selectionView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
			selectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
		])

		imageWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: 32)
		imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: 32)

		imageLeadingConstraint = imageView.leadingAnchor.constraint(
			equalTo: leadingAnchor, constant: contentInsets.left)
		imageCenterYConstraint = imageView.centerYAnchor.constraint(equalTo: centerYAnchor)

		titleLeadingWithImage = titleLabel.leadingAnchor.constraint(
			equalTo: imageView.trailingAnchor, constant: 8)
		titleLeadingWithoutImage = titleLabel.leadingAnchor.constraint(
			equalTo: leadingAnchor, constant: contentInsets.left)

		titleLeadingWithImage?.isActive = false
		titleLeadingWithoutImage?.isActive = false

		NSLayoutConstraint.activate([
			imageLeadingConstraint!,
			imageCenterYConstraint!,
			imageWidthConstraint!,
			imageHeightConstraint!,

			titleLabel.trailingAnchor.constraint(
				equalTo: trailingAnchor, constant: -contentInsets.right),
			titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),

			subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
			subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
			subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
			subtitleLabel.bottomAnchor.constraint(
				lessThanOrEqualTo: bottomAnchor, constant: -contentInsets.bottom),
		])
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

	private func updateImageVisibility() {
		let hasImage = imageView.image != nil

		imageView.isHidden = !hasImage

		imageLeadingConstraint?.isActive = hasImage
		imageCenterYConstraint?.isActive = hasImage
		imageWidthConstraint?.isActive = hasImage
		imageHeightConstraint?.isActive = hasImage

		titleLeadingWithImage?.isActive = false
		titleLeadingWithoutImage?.isActive = false
		if hasImage {
			titleLeadingWithImage?.isActive = true
		} else {
			titleLeadingWithoutImage?.isActive = true
		}

		needsUpdateConstraints = true
		invalidateIntrinsicContentSize()
	}

	private func updateTextColorsForHover() {
		if isHovered {
			titleLabel.textColor = NSColor.selectedMenuItemTextColor
			subtitleLabel.textColor = NSColor.selectedMenuItemTextColor.withAlphaComponent(0.75)
		} else {
			titleLabel.textColor = NSColor.labelColor
			subtitleLabel.textColor = NSColor.secondaryLabelColor
		}
	}

	// MARK: - Public Methods

	public func configure(title: String, subtitle: String?, image: NSImage?) {
		self.title = title
		self.subtitle = subtitle
		if let img = image {
			self.image = img
		} else {
			self.image = nil
		}
		updateImageVisibility()
	}

	// MARK: - Overrides

	override var intrinsicContentSize: NSSize {
		let baseHeight: CGFloat = subtitleLabel.isHidden ? 18 : 30
		let height = contentInsets.top + baseHeight + contentInsets.bottom
		return NSSize(width: fixedWidth, height: ceil(height))
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		setupTrackingArea()
	}

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		super.viewWillMove(toWindow: newWindow)
		if newWindow == nil {
			isHovered = false
		}
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		updateTrackingAreas()
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
		guard let item = self.enclosingMenuItem else { return }

		if item.hasSubmenu {
			return
		}

		guard let menu = item.menu else {
			NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
			return
		}

		let index = menu.index(of: item)
		if index != -1 {

			menu.performActionForItem(at: index)
		}

		NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
	}
}
