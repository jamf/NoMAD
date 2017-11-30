//
//  NoADApplication.swift
//  NoAD
//
//  Created by Boushy, Phillip on 5/11/16.
//  Copyright © 2016 Orchard & Grove Inc. All rights reserved.
//

// This lets copy/paste and other shortcuts work in NoMAD windows
// Otherwise since it's a menu item only it can't do that

import Cocoa

@objc protocol UndoActionRespondable {
    func undo(_ sender: AnyObject)
}

@objc protocol RedoActionRespondable {
    func redo(_ sender: AnyObject)
}

class NoMADApplication: NSApplication {
    fileprivate let commandKey = NSEvent.ModifierFlags.command.rawValue
    fileprivate let commandShiftKey = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue

    override func sendEvent(_ event: NSEvent) {
        if event.type == NSEvent.EventType.keyDown {
            if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue == commandKey) {
                switch event.charactersIgnoringModifiers!.lowercased() {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to:nil, from:self) { return }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to:nil, from:self) { return }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to:nil, from:self) { return }
                case "z":
                    if NSApp.sendAction(#selector(UndoActionRespondable.undo(_:)), to:nil, from:self) { return }
                case "a":
                    if NSApp.sendAction(#selector(NSText.selectAll(_:)), to:nil, from:self) { return }
                case "b":
                    if NSApp.sendAction(#selector(NoMADMenuController.logEntireUserRecord), to: NoMADMenuController.self, from: self) { return }
                case "w":
                    NSApp.keyWindow?.close()
                default:
                    break
                }
            }
            else if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue == commandShiftKey) {
                if event.charactersIgnoringModifiers == "Z" {
                    if NSApp.sendAction(#selector(RedoActionRespondable.redo(_:)), to:nil, from:self) { return }
                }
            }
        }
        super.sendEvent(event)
    }

}


