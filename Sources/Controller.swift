import Cocoa
import InputMethodKit
import Carbon.HIToolbox

var sharedCandidates: IMKCandidates!

@objc(FinglishInputController)
class FinglishInputController: IMKInputController {
    private var buffer = ""
    private var cands: [String] = []
    private var pending: DispatchWorkItem?

    private let punctuation: [Character: String] = ["?": "؟", ",": "،", ";": "؛"]
    private let persianDigits = Array("۰۱۲۳۴۵۶۷۸۹")
    private let noRange = NSRange(location: NSNotFound, length: NSNotFound)

    private var digitsEnabled: Bool { UserDefaults.standard.bool(forKey: "persianDigits") }
    private var googleEnabled: Bool { UserDefaults.standard.object(forKey: "googleOnline") as? Bool ?? true }

    // MARK: key handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        let composing = !buffer.isEmpty

        // Shortcuts (⌘A, ⌘V, …): keep what was typed as plain Latin text and let the app handle the shortcut.
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            if composing { commit(buffer, client) }
            return false
        }
        switch event.keyCode {
        case 36, 76:
            guard composing else { return false }
            commitSelected(client); return true
        case 49:
            guard composing else { return false }
            commitSelected(client); insert(" ", client); return true
        case 51:
            guard composing else { return false }
            buffer.removeLast(); refresh(client); return true
        case 53:
            guard composing else { return false }
            reset(client); return true
        case 123, 124, 125, 126, 48:
            guard composing else { return false }
            sharedCandidates.interpretKeyEvents([event]); return true
        default: break
        }

        guard let chars = event.characters, chars.count == 1, let ch = chars.first else { return false }
        if ch.isASCII, ch.isLetter || ch == "'" {
            buffer.append(Character(ch.lowercased()))
            refresh(client); return true
        }
        if ch.isASCII, let d = ch.wholeNumberValue, composing, d >= 1, d <= min(9, cands.count) {
            commit(cands[d - 1], client); return true
        }
        if composing { commitSelected(client) }
        if let p = punctuation[ch] { insert(p, client); return true }
        if ch.isASCII, let d = ch.wholeNumberValue, digitsEnabled { insert(String(persianDigits[d]), client); return true }
        if composing, ch.isASCII { insert(String(ch), client); return true }
        return false
    }

    // MARK: composition

    private func refresh(_ client: IMKTextInput) {
        pending?.cancel()
        if buffer.isEmpty { reset(client); return }
        cands = Engine.shared.localCandidates(for: buffer)
        client.setMarkedText(buffer, selectionRange: NSRange(location: buffer.utf16.count, length: 0), replacementRange: noRange)
        sharedCandidates.update()
        sharedCandidates.show()

        guard googleEnabled, !IsSecureEventInputEnabled() else { return }
        let word = buffer
        let work = DispatchWorkItem { [weak self] in
            Engine.shared.fetchGoogle(word) { [weak self] words in
                guard let self, self.buffer == word else { return }   // user kept typing: drop stale answer
                self.cands = Engine.shared.merged(google: words, for: word)
                sharedCandidates.update()
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func reset(_ client: IMKTextInput?) {
        pending?.cancel(); Engine.shared.cancelFetch()
        client?.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: noRange)
        buffer = ""; cands = []
        sharedCandidates?.hide()
    }

    private func insert(_ text: String, _ client: IMKTextInput) { client.insertText(text, replacementRange: noRange) }

    private func commit(_ text: String, _ client: IMKTextInput) {
        if text != buffer { Engine.shared.learn(buffer, text) }
        insert(text, client)
        reset(client)
    }

    private func commitSelected(_ client: IMKTextInput) {
        let picked = sharedCandidates.selectedCandidateString()?.string
        commit(picked.flatMap { cands.contains($0) ? $0 : nil } ?? cands.first ?? buffer, client)
    }

    // MARK: IMKInputController overrides

    override func candidates(_ sender: Any!) -> [Any]! { cands }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        if let client = client() { commit(candidateString.string, client) }
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = (sender as? IMKTextInput) ?? client(), !buffer.isEmpty else { return }
        commitSelected(client)
    }

    override func deactivateServer(_ sender: Any!) {
        if let client = sender as? IMKTextInput, !buffer.isEmpty { commitSelected(client) }
        sharedCandidates?.hide()
        super.deactivateServer(sender)
    }

    override func menu() -> NSMenu! {
        let m = NSMenu()
        let g = NSMenuItem(title: "Use Google online", action: #selector(toggleGoogle), keyEquivalent: "")
        g.target = self; g.state = googleEnabled ? .on : .off
        m.addItem(g)
        let d = NSMenuItem(title: "Persian digits (۱۲۳)", action: #selector(toggleDigits), keyEquivalent: "")
        d.target = self; d.state = digitsEnabled ? .on : .off
        m.addItem(d)
        return m
    }

    @objc private func toggleGoogle() { UserDefaults.standard.set(!googleEnabled, forKey: "googleOnline") }
    @objc private func toggleDigits() { UserDefaults.standard.set(!digitsEnabled, forKey: "persianDigits") }
}
