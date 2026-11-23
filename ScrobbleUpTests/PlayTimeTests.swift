import Foundation
import Testing

@testable import scrobble_up

struct PlayTimeTests {
	let t0 = Date(timeIntervalSince1970: 1_000_000)

	@Test func pauseDoesNotCountAndResumeContinues() {
		var time = PlayTime()
		time.resume(at: t0)
		time.pause(at: t0 + 20)  // played 20s
		#expect(time.played(at: t0 + 100) == 20)  // paused for 80s: not counted

		time.resume(at: t0 + 100)
		time.resume(at: t0 + 110)  // duplicate "playing" event must not reset the clock
		#expect(time.played(at: t0 + 130) == 50)

		// 200s track at 50%: 100s needed, so 50s left after resume.
		#expect(PlayTime.threshold(duration: 200, percent: 50) - time.played(at: t0 + 130) == 50)
	}

	@Test func thresholdIsClampedBetween30sAnd4Minutes() {
		#expect(PlayTime.threshold(duration: 40, percent: 50) == 30)
		#expect(PlayTime.threshold(duration: 1200, percent: 50) == 240)
	}

	@Test func repeatIsSeenOnlyAfterTheTrackPlayedToTheEnd() {
		var time = PlayTime()
		time.resume(at: t0)
		#expect(!time.isRepeat(duration: 180, at: t0 + 90))
		#expect(time.isRepeat(duration: 180, at: t0 + 179))
	}
}
