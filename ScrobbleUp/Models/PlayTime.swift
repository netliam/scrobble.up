import Foundation

/// How long one track has really played, not counting pauses.
/// Takes `now` as a parameter so the rules can be unit tested.
nonisolated struct PlayTime: Equatable {
	private var playedBefore: TimeInterval = 0  // play time before the last pause
	private var resumedAt: Date?  // nil while paused

	var isPlaying: Bool { resumedAt != nil }

	mutating func resume(at now: Date) {
		if resumedAt == nil { resumedAt = now }
	}

	mutating func pause(at now: Date) {
		guard let resumedAt else { return }
		playedBefore += now.timeIntervalSince(resumedAt)
		self.resumedAt = nil
	}

	func played(at now: Date) -> TimeInterval {
		playedBefore + (resumedAt.map { now.timeIntervalSince($0) } ?? 0)
	}

	// shortcut: a repeat is only seen when the track played to its end; seek-then-repeat is missed,
	// and a stray "playing" event in the last 2s is read as a repeat.
	func isRepeat(duration: Int, at now: Date) -> Bool {
		duration > 0 && played(at: now) >= TimeInterval(duration - 2)
	}

	/// Play time needed before a track counts: `percent` of it, at least 30s, at most 4 minutes.
	static func threshold(duration: Int, percent: Int) -> TimeInterval {
		TimeInterval(min(max(30, duration * percent / 100), 240))
	}
}
