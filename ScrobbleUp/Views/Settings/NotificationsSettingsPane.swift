//
//  NotificationsSettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import SwiftUI

struct NotificationsSettingsPane: View {
	@AppStorage(\.ratingAndLoveStatus) private var ratingAndLoveStatus
	@AppStorage(\.infoCopiedToClipboard) private var infoCopiedToClipboard

	var body: some View {
		Form {
			Section("HUD Notifications") {
				Toggle("Show HUD for rating and love status", isOn: $ratingAndLoveStatus)
				Toggle("Show HUD for copying to clipboard", isOn: $infoCopiedToClipboard)
			}
		}
		.formStyle(.grouped)
		.frame(width: 450)
	}
}

#Preview {
	NotificationsSettingsPane()
}
