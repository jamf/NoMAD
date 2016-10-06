//
//  Extensions.swift
//  NoMAD
//
//  Created by Boushy, Phillip on 10/4/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

import Foundation

extension NSWindow {
	func forceToFrontAndFocus(sender: AnyObject?) {
		NSApp.activateIgnoringOtherApps(true)
		self.makeKeyAndOrderFront(sender);
	}
}

extension String {
	var translate: String {
		return Localizator.sharedInstance.translate(self)
	}
}
