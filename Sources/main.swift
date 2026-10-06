import Cocoa
import InputMethodKit

let connection = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "FinglishIME_Connection"
let server = IMKServer(name: connection, bundleIdentifier: Bundle.main.bundleIdentifier)
sharedCandidates = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
sharedCandidates.setSelectionKeys([18, 19, 20, 21, 23, 22, 26, 28, 25])
sharedCandidates.setAttributes([IMKCandidatesSendServerKeyEventFirst: true as NSNumber])
NSApplication.shared.run()
