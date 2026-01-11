//
//  MenuItemStatsRowView.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import Cocoa

class MenuItemStatsRowView: NSView {

	private let width: CGFloat

	private let leftLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = .systemFont(ofSize: 13)
		label.textColor = .labelColor
		return label
	}()

	private let rightLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
		label.textColor = .labelColor
		label.alignment = .right
		return label
	}()

	// MARK: - Initializers

	init(width: CGFloat, leftText: String, rightText: String = "—") {
		self.width = width
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		wantsLayer = true
		leftLabel.stringValue = leftText
		rightLabel.stringValue = rightText
		setupViews()
	}

	required init?(coder: NSCoder) {
		return nil
	}

	// MARK: - Setup

	private func setupViews() {
		addSubview(leftLabel)
		addSubview(rightLabel)

		let horizontalInset: CGFloat = 15

		NSLayoutConstraint.activate([
			leftLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
			leftLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

			rightLabel.trailingAnchor.constraint(
				equalTo: trailingAnchor, constant: -horizontalInset),
			rightLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
	}

	// MARK: - Public Methods

	func updateValue(_ value: String) {
		rightLabel.stringValue = value
	}

	// MARK: - Overrides

	override var intrinsicContentSize: NSSize {
		return NSSize(width: width, height: 20)
	}
}
