//
//  NotificationsSettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import SwiftUI

struct NotificationsSettingsPane: View {
	@AppStorage(\.ratingStatus) private var ratingStatus
	@AppStorage(\.infoCopied) private var infoCopied

	var body: some View {
		Form {
			Section("HUD Notifications") {
				Toggle("Show HUD for rating and love status", isOn: $ratingStatus)
				Toggle("Show HUD for copying to clipboard", isOn: $infoCopied)
			}
		}
		.formStyle(.grouped)
		.frame(width: 450)
	}
}

#Preview {
	NotificationsSettingsPane()
}
