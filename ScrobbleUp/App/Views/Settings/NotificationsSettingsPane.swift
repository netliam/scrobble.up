//
//  NotificationsSettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import Defaults
import SwiftUI

struct NotificationsSettingsPane: View {
  @Default(.ratingAndLoveStatusInHUD) private var ratingAndLoveStatusInHUD
  @Default(.infoCopiedToClipboardInHUD) private var infoCopiedToClipboardInHUD

  var body: some View {
    Form {
      Section("HUD Notifications") {
        Toggle("Show HUD for rating and love status", isOn: $ratingAndLoveStatusInHUD)
        Toggle("Show HUD for copying to clipboard", isOn: $infoCopiedToClipboardInHUD)
      }
    }
    .formStyle(.grouped)
    .frame(width: 450)
  }
}

#Preview {
  NotificationsSettingsPane()
}
