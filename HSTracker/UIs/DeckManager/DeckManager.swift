//
//  DeckManager.swift
//  HSTracker
//
//  Created by Benjamin Michotte on 23/02/16.
//  Copyright © 2016 Benjamin Michotte. All rights reserved.
//

import Foundation
import CleanroomLogger

class DeckManager: NSWindowController {

    @IBOutlet weak var decksTable: NSTableView!
    @IBOutlet weak var deckListTable: NSTableView!
    @IBOutlet weak var curveView: CurveView!
    @IBOutlet weak var statsLabel: NSTextField!
    @IBOutlet weak var progressView: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var archiveToolBarItem: NSToolbarItem!

    @IBOutlet weak var druidButton: NSButton!
    @IBOutlet weak var hunterButton: NSButton!
    @IBOutlet weak var mageButton: NSButton!
    @IBOutlet weak var paladinButton: NSButton!
    @IBOutlet weak var priestButton: NSButton!
    @IBOutlet weak var rogueButton: NSButton!
    @IBOutlet weak var shamanButton: NSButton!
    @IBOutlet weak var warlockButton: NSButton!
    @IBOutlet weak var warriorButton: NSButton!
    @IBOutlet weak var archiveButton: NSButton!
    @IBOutlet weak var toolbar: NSToolbar!

    var editDeck: EditDeck?
    var newDeck: NewDeck?
    var hearthstatsLogin: HearthstatsLogin?

    var decks = [Deck]()
    var classes = [String]()
    var currentClass: String?
    var currentDeck: Deck?
    var currentCell: DeckCellView?
    var showArchivedDecks = false

    override func windowDidLoad() {
        super.windowDidLoad()

        let nib = NSNib(nibNamed: "DeckCellView", bundle: nil)
        decksTable.registerNib(nib, forIdentifier: "DeckCellView")

        decksTable.backgroundColor = NSColor.clearColor()
        decksTable.autoresizingMask = [NSAutoresizingMaskOptions.ViewWidthSizable,
                                       NSAutoresizingMaskOptions.ViewHeightSizable]

        decksTable.tableColumns.first?.width = NSWidth(decksTable.bounds)
        decksTable.tableColumns.first?.resizingMask = NSTableColumnResizingOptions.AutoresizingMask

        decksTable.target = self
        decksTable.action = #selector(DeckManager.decksTableClick(_:))

        decks = Decks.instance.decks().filter({$0.isActive})
        decksTable.reloadData()

        deckListTable.tableColumns.first?.width = NSWidth(deckListTable.bounds)
        deckListTable.tableColumns.first?.resizingMask = .AutoresizingMask

        NSEvent.addLocalMonitorForEventsMatchingMask(.KeyDownMask) { (e) -> NSEvent? in
            let isCmd = e.modifierFlags.contains(.CommandKeyMask)
            // let isShift = e.modifierFlags.contains(.ShiftKeyMask)

            guard isCmd else { return e }

            switch e.keyCode {
            case 45:
                self.addDeck(self)
                return nil

            default:
                Log.verbose?.message("unsupported keycode \(e.keyCode)")
                break
            }

            return e
        }

        NSNotificationCenter.defaultCenter()
            .addObserver(self,
                         selector: #selector(DeckManager.updateStatsLabel),
                         name: "reload_decks",
                         object: nil)

        NSNotificationCenter.defaultCenter()
            .addObserver(self,
                         selector: #selector(DeckManager.updateTheme(_:)),
                         name: "theme",
                         object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func filteredDecks() -> [Deck] {
        if let currentClass = currentClass {
            return decks.filter({ $0.playerClass == currentClass && $0.isActive == true })
                .sort { $0.name < $1.name }
        } else if showArchivedDecks {
            return decks.filter({ $0.isActive != true }).sort { $0.name < $1.name }
        } else {
            return decks.filter({ $0.isActive == true }).sort { $0.name < $1.name }
        }
    }

    @IBAction func filterClassesAction(sender: NSButton) {
        let buttons = [druidButton, hunterButton, mageButton,
            paladinButton, priestButton, rogueButton,
            shamanButton, warlockButton, warriorButton,
            archiveButton
        ]
        for button in buttons {
            if sender != button {
                button.state = NSOffState
            }
        }

        let oldCurrentClass = currentClass
        if sender == druidButton {
            currentClass = "druid"
        } else if sender == hunterButton {
            currentClass = "hunter"
        } else if sender == mageButton {
            currentClass = "mage"
        } else if sender == paladinButton {
            currentClass = "paladin"
        } else if sender == priestButton {
            currentClass = "priest"
        } else if sender == rogueButton {
            currentClass = "rogue"
        } else if sender == shamanButton {
            currentClass = "shaman"
        } else if sender == warlockButton {
            currentClass = "warlock"
        } else if sender == warriorButton {
            currentClass = "warrior"
        } else {
            currentClass = nil
        }

        showArchivedDecks = sender == archiveButton

        if currentClass == oldCurrentClass && currentDeck == nil {
            currentClass = nil
        }

        refreshDecks()
    }

    func decksTableClick(sender: AnyObject?) {
        guard sender?.clickedRow >= 0 else {
            return
        }
        let clickedRow = sender!.clickedRow!
        currentDeck = filteredDecks()[clickedRow]
        let labelName = ((currentDeck?.isActive) == true) ? "Archive" : "Unarchive"
        self.archiveToolBarItem.label = NSLocalizedString(labelName, comment: "")
        deckListTable.reloadData()
        curveView.deck = currentDeck
        updateStatsLabel()

        toolbar.validateVisibleItems()
    }

    func updateStatsLabel() {
        if let currentDeck = self.currentDeck {
            dispatch_async(dispatch_get_main_queue()) {
                self.statsLabel.stringValue = currentDeck.displayStats()
                self.curveView.reload()
            }
        }
    }

    func updateTheme(notification: NSNotification) {
        deckListTable.reloadData()
    }

    // MARK: - Toolbar actions
    override func validateToolbarItem(item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case "add", "donate", "twitter", "hearthstats":
            return true
        case "edit", "use", "delete", "rename", "archive":
            return currentDeck != nil
        default:
            return false
        }
    }

    @IBAction func addDeck(sender: AnyObject) {
        newDeck = NewDeck(windowNibName: "NewDeck")
        if let newDeck = newDeck {
            newDeck.setDelegate(self)
            self.window!.beginSheet(newDeck.window!, completionHandler: nil)
        }
    }

    @IBAction func hearthstatsLogin(sender: AnyObject) {
        if HearthstatsAPI.isLogged() {
            let alert = NSAlert()
            alert.alertStyle = .InformationalAlertStyle
            // swiftlint:disable line_length
            alert.messageText = NSLocalizedString("Are you sure you want to disconnect from Hearthstats ?", comment: "")
            // swiftlint:enable line_length
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.addButtonWithTitle(NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModalForWindow(self.window!,
                                           completionHandler: { (returnCode) in
                                            if returnCode == NSAlertFirstButtonReturn {
                                                HearthstatsAPI.logout()
                                            }
            })
        } else {
            hearthstatsLogin = HearthstatsLogin(windowNibName: "HearthstatsLogin")
            if let hearthstatsLogin = hearthstatsLogin {
                self.window!.beginSheet(hearthstatsLogin.window!, completionHandler: nil)
            }
        }
    }

    @IBAction func donate(sender: AnyObject) {
        // swiftlint:disable line_length
        let url = NSURL(string: "https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=bmichotte%40gmail%2ecom&lc=US&item_name=HSTracker&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted")
        // swiftlint:enable line_length
        NSWorkspace.sharedWorkspace().openURL(url!)
    }

    @IBAction func twitter(sender: AnyObject) {
        let url = NSURL(string: "https://twitter.com/hstracker_mac")
        NSWorkspace.sharedWorkspace().openURL(url!)
    }

    @IBAction func renameDeck(sender: AnyObject?) {
        // swiftlint:disable line_length
        if let deck = currentDeck {
            let deckNameInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
            deckNameInput.stringValue = deck.name!
            let alert = NSAlert()
            alert.alertStyle = .InformationalAlertStyle
            alert.messageText = NSLocalizedString("Deck name", comment: "")
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.addButtonWithTitle(NSLocalizedString("Cancel", comment: ""))
            alert.accessoryView = deckNameInput
            alert.beginSheetModalForWindow(self.window!,
                                           completionHandler: { (returnCode) in
                                            if returnCode == NSAlertFirstButtonReturn {
                                                deck.name = deckNameInput.stringValue
                                                Decks.instance.update(deck)

                                                if HearthstatsAPI.isLogged() {
                                                    if Settings.instance.hearthstatsAutoSynchronize {
                                                        do {
                                                            try HearthstatsAPI.updateDeck(deck) {_ in}
                                                        } catch {}
                                                    } else {
                                                        // TODO Alert synchro
                                                    }
                                                }

                                                self.refreshDecks()
                                            }
            })
        }
        // swiftlint:enable line_length
    }

    @IBAction func editDeck(sender: AnyObject?) {
        if let deck = currentDeck {
            editDeck = EditDeck(windowNibName: "EditDeck")
            if let editDeck = editDeck {
                editDeck.setDeck(deck)
                editDeck.setPlayerClass(deck.playerClass)
                editDeck.setDelegate(self)
                editDeck.showWindow(self)
            }
        }
    }

    @IBAction func useDeck(sender: AnyObject?) {
        if let deck = currentDeck {
            Settings.instance.activeDeck = deck.deckId
            Game.instance.setActiveDeck(deck)
            Game.instance.updatePlayerTracker()
        }
    }

    @IBAction func deleteDeck(sender: AnyObject?) {
        if let deck = currentDeck {
            let alert = NSAlert()
            alert.alertStyle = .InformationalAlertStyle
            // swiftlint:disable line_length
            alert.messageText = NSString(format: NSLocalizedString("Are you sure you want to delete the deck %@ ?", comment: ""), deck.name!) as String
            // swiftlint:enable line_length
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.addButtonWithTitle(NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModalForWindow(self.window!,
                                           completionHandler: { (returnCode) in
                                            if returnCode == NSAlertFirstButtonReturn {
                                                self._deleteDeck(deck)
                                            }
            })
        }
    }

    @IBAction func archiveDeck(sender: AnyObject) {
        if let deck = currentDeck {
            let alert = NSAlert()
            alert.alertStyle = .InformationalAlertStyle
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.addButtonWithTitle(NSLocalizedString("Cancel", comment: ""))

            if deck.isActive {
                alert.messageText = NSString(format:
                    NSLocalizedString("Are you sure you want to archive the deck %@ ?",
                        comment: ""), deck.name!) as String
            } else {
                alert.messageText = NSString(format:
                    NSLocalizedString("Are you sure you want to unarchive the deck %@ ?",
                        comment: ""), deck.name!) as String
            }
            alert.beginSheetModalForWindow(self.window!,
                                           completionHandler: { (returnCode) in
                                            if returnCode == NSAlertFirstButtonReturn {
                                                deck.isActive = !deck.isActive
                                                Settings.instance.activeDeck = nil
                                                self.refreshDecks()
                                                Decks.instance.save()
                                            }
            })
        }
    }

    private func _deleteDeck(deck: Deck) {
        // swiftlint:disable line_length
        Log.verbose?.message("in delete \(deck) -> \(HearthstatsAPI.isLogged()) -> \(Settings.instance.hearthstatsAutoSynchronize)")
        if let _ = deck.hearthstatsId where HearthstatsAPI.isLogged() {
            if Settings.instance.hearthstatsAutoSynchronize {
                do {
                    try HearthstatsAPI.deleteDeck(deck)
                } catch {
                    print("error delete hearthstats")
                }
                Decks.instance.remove(deck)
                refreshDecks()
            } else {
                let alert = NSAlert()
                alert.alertStyle = .InformationalAlertStyle
                alert.messageText = NSLocalizedString("Do you want to delete the deck on Hearthstats ?", comment: "")
                alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
                alert.addButtonWithTitle(NSLocalizedString("Cancel", comment: ""))
                alert.beginSheetModalForWindow(self.window!,
                                               completionHandler: { (returnCode) in
                                                if returnCode == NSAlertFirstButtonReturn {
                                                    do {
                                                        try HearthstatsAPI.deleteDeck(deck)
                                                    } catch {
                                                        // TODO alert
                                                        print("error delete hearthstats")
                                                    }
                                                    Decks.instance.remove(deck)
                                                    self.refreshDecks()
                                                }
                })
            }
        } else {
            Decks.instance.remove(deck)
            refreshDecks()
        }
        // swiftlint:enable line_length
    }
}

// MARK: - NSTableViewDelegate
extension DeckManager: NSTableViewDelegate {
    func tableView(tableView: NSTableView,
                   viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == decksTable {
            if let cell = decksTable?.makeViewWithIdentifier("DeckCellView", owner: self)
                as? DeckCellView {

                let deck = filteredDecks()[row]
                cell.deck = deck
                cell.label.stringValue = deck.name!
                cell.image.image = NSImage(named: deck.playerClass.lowercaseString)
                cell.color = ClassColor.color(deck.playerClass)
                cell.selected = tableView.selectedRow == -1 || tableView.selectedRow == row

                return cell
            }
        } else {
            let cell = CardBar.factory()
            cell.playerType = .DeckManager
            cell.card = currentDeck?.sortedCards[row]
            return cell
        }

        return nil
    }

    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView == self.decksTable {
            return 55
        } else if tableView == self.deckListTable {
            return CGFloat(kRowHeight)
        }
        return 20
    }

    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        let decks = filteredDecks().count
        guard decks == notification.object?.numberOfRows else { return }
        for i in 0 ..< decks {
            let row = decksTable?.viewAtColumn(0, row: i, makeIfNecessary: false) as? DeckCellView
            row?.selected = decksTable?.selectedRow == -1 || decksTable?.selectedRow == i
        }
        decksTable?.setNeedsDisplay()
    }
}

// MARK: - NSTableViewDataSource
extension DeckManager: NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if tableView == decksTable {
            return filteredDecks().count
        } else if let currentDeck = currentDeck {
            return currentDeck.sortedCards.count
        }

        return 0
    }
}

// MARK: - NewDeckDelegate
extension DeckManager: NewDeckDelegate {
    func addNewDeck(deck: Deck) {
        refreshDecks()
    }

    func openDeckBuilder(playerClass: String, arenaDeck: Bool) {
        editDeck = EditDeck(windowNibName: "EditDeck")
        if let editDeck = editDeck {
            let deck = Deck(playerClass: playerClass)
            deck.isArena = arenaDeck
            editDeck.setDeck(deck)
            editDeck.setPlayerClass(playerClass)
            editDeck.setDelegate(self)
            editDeck.showWindow(self)
        }
    }

    func refreshDecks() {
        // Guard incase we are creating a new deck without the window loaded
        guard windowLoaded else { return }
        currentDeck = nil
        decksTable.deselectAll(self)
        decks = Decks.instance.decks()
        classes = [String]()
        for deck in decks {
            if !classes.contains(deck.playerClass) {
                classes.append(deck.playerClass)
            }
        }
        decksTable.reloadData()
    }
}
