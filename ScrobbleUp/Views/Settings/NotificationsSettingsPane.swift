//
//  NotificationsSettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import SwiftUI

struct NotificationsSettingsPane: View {
	@AppStorage(\.showNotifications) private var showNotifications
	@AppStorage(\.updateNotifications) private var updateNotifications
	@AppStorage(\.ratingStatus) private var ratingStatus
	@AppStorage(\.infoCopied) private var infoCopied

	var body: some View {
		Form {
			Section("General") {
				Toggle("Show notifications", isOn: $showNotifications)
					.onChange(of: showNotifications) { oldValue, newValue in
						if !newValue {
							updateNotifications = false
							ratingStatus = false
							infoCopied = false
						}
					}
				Toggle("Show notification for updates", isOn: $updateNotifications).disabled(
					!showNotifications)
			}
			Section("HUD") {
				Toggle("Show HUD for rating and love status", isOn: $ratingStatus).disabled(
					!showNotifications)
				Toggle("Show HUD for copying to clipboard", isOn: $infoCopied).disabled(
					!showNotifications)
			}
		}
		.formStyle(.grouped)
		.frame(width: 450)
	}
}

#Preview {
	NotificationsSettingsPane()
}
