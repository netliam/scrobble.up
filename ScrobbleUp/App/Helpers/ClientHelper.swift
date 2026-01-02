//
//  ClientHelper.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import Foundation
import LastFM

func bestImageURL(images: LastFMImages) -> URL? {
	return images.mega
		?? images.extraLarge
		?? images.large
		?? images.medium
		?? images.small
}
