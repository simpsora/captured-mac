//
//  AppDelegate.swift
//  Captured
//
//  Created by Christopher Sexton on 11/20/15.
//  Copyright © 2015 Christopher Sexton. All rights reserved.
//

import Cocoa
import AppKit
import Carbon
import MASShortcut



@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  var accountManager = AccountManager.sharedInstance
  var shortcutManager = ShortcutManager.sharedInstance
  var shortcutMonitor = MASShortcutMonitor.sharedMonitor()

  // The magic tag that is used to denote a menu item is for a "shortcut." This
  // is used to remove all menu items associated with a tag.
  let magicShortcutMenuItemTag = 13

  // MARK: App Delegates

  func applicationWillFinishLaunching(notification: NSNotification) {
    // Prevent launching and process the command line
  }

  func applicationDidFinishLaunching(aNotification: NSNotification) {

    setDefaultDefaults()
    accountManager.load()
    shortcutManager.load()
    createStatusMenu()

    registerShortcuts()
    setupNotificationListeners()
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your applicat
  }

  func setDefaultDefaults() {
    if let path = NSBundle.mainBundle().pathForResource("Defaults", ofType: "plist") {
      let defaultDict: [String : AnyObject] = NSDictionary(contentsOfFile: path)! as! [String : AnyObject]
      NSUserDefaults.standardUserDefaults().registerDefaults(defaultDict)
    }
  }

  // MARK: Preferences Window

  var preferencesController: NSWindowController?

  @IBAction func showPreferences(sender : AnyObject) {

    NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    if (preferencesController == nil) {
      let storyboard = NSStoryboard(name: "Preferences", bundle: nil)
      preferencesController = storyboard.instantiateInitialController() as? NSWindowController
    }
    if (preferencesController != nil) {
      preferencesController!.showWindow(sender)
    }
  }

  // MARK: Status Menu

  let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)

  func createStatusMenu() {
    setGlobalState(.Normal)
    let menu = NSMenu()

    menu.addItem(NSMenuItem(title: "Preferences...", action: Selector("showPreferences:"), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separatorItem())

    statusItem.menu = menu
  }

  func setGlobalState(state:CapturedState.States) {
    if let button = statusItem.button {
      let image = imageForState(state)
      button.image = image
    }
  }

  func imageForState(status:CapturedState.States) -> NSImage {
    var img : NSImage?

    switch(status) {
    case .Normal:
      img = NSImage(named: "StatusMenu")!
      img!.template = true
    case .Disabled:
      img = NSImage(named: "StatusMenuDisabled")!
      img!.template = true
    case .Active:
      img = NSImage(named: "StatusMenuActive")!
    case .Success:
      img = NSImage(named: "StatusMenuSuccess")!
    case .Error:
      img = NSImage(named: "StatusMenuError")!
    }

    return img!
  }

  // MARK: Global App State

  func stateDidChange(state:CapturedState) {
    print(state.current)
    setGlobalState(state.current)

  }

  // MARK: Manage Global HotKey and Shortcuts

  private func setupNotificationListeners() {
    let nc = NSNotificationCenter.defaultCenter()
    let shortcut = CapturedNotifications.ShortcutsDidUpdate.rawValue
    let state = CapturedNotifications.StateDidChange.rawValue
    
    nc.addObserver(self, selector: "registerShortcuts", name: shortcut, object: nil)
    nc.addObserverForName(shortcut, object: nil, queue: nil) { _ in
      self.registerShortcuts()
    }
    
    nc.addObserverForName(state, object: nil, queue: nil) { notification in
      if let info = notification.userInfo as? [String:AnyObject] {
//        if let s = info["state"] as? Int, newState = CapturedState(rawValue: s) {
//          self.stateDidChange(newState)
//        }
        if let s = info["state"] as? CapturedState {
          self.stateDidChange(s)
        }
      }
    }
  }

  func registerShortcuts() {
    var items = [NSMenuItem]()
    for item in statusItem.menu!.itemArray {
      if (item.tag == magicShortcutMenuItemTag) {
        items.append(item)
      }
    }

    for item in items {
      statusItem.menu!.removeItem(item)
    }

    shortcutMonitor.unregisterAllShortcuts()
    shortcutManager.each { (shortcut) -> (Void) in
      self.registerHotKey(shortcut)
      self.createShortcutMenu(shortcut)
    }
  }

  private func registerHotKey(shortcut:Shortcut) {
    if let sc = shortcut.shortcutValue {
      shortcutMonitor.registerShortcut(sc) {
        self.runShortcut(shortcut)
      }
    }
  }

  private func createShortcutMenu(shortcut:Shortcut) {
    if let sc = shortcut.shortcutValue {
      let menuItem = NSMenuItem(title: shortcut.name, action: Selector("menuShortcut:"), keyEquivalent: sc.keyCodeString)
      menuItem.keyEquivalentModifierMask = Int(sc.modifierFlags)
      menuItem.representedObject = shortcut
      menuItem.tag = magicShortcutMenuItemTag

      statusItem.menu!.addItem(menuItem)
    }
  }

  private func runShortcut(shortcut:Shortcut) {
    Command(shortcut: shortcut).runAsync()
  }

  @IBAction func menuShortcut(sender:NSMenuItem) {
    print(sender.representedObject)
    if let shortcut = sender.representedObject as? Shortcut {
      runShortcut(shortcut)
    }
  }

}

