//
//  MenuItemHeaderView.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import Cocoa

class MenuItemHeaderView: NSView {

	private let width: CGFloat

	private let titleLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = .systemFont(ofSize: 13, weight: .semibold)
		label.textColor = .labelColor
		return label
	}()

	private let rightLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = .systemFont(ofSize: 13, weight: .semibold)
		label.textColor = .labelColor
		return label
	}()

	// MARK: - Initializers

	init(width: CGFloat, title: String, rightText: String = "") {
		self.width = width
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		wantsLayer = true
		titleLabel.stringValue = title
		self.rightLabel.stringValue = rightText
		setupViews()
	}

	required init?(coder: NSCoder) {
		return nil
	}

	// MARK: - Setup

	private func setupViews() {
		addSubview(titleLabel)
		addSubview(rightLabel)

		let horizontalInset: CGFloat = 15

		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
			titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

			rightLabel.trailingAnchor.constraint(
				equalTo: trailingAnchor, constant: -horizontalInset),
			rightLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
	}

	// MARK: - Public Methods

	func updateRightLabel(_ text: String) {
		rightLabel.stringValue = text
	}

	// MARK: - Overrides

	override var intrinsicContentSize: NSSize {
		return NSSize(width: width, height: 28)
	}
}
