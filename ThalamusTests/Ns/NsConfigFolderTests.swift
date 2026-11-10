import Testing
import Foundation
@testable import Thalamus

@Test func aFolderIsExportedAsNsConfigDirWithTheTildeExpanded() {
    var exported: [String: String] = [:]

    NsConfigFolder.export("~/.config/ns-dev") { exported[$0] = $1 }

    #expect(exported == ["NS_CONFIG_DIR": NSHomeDirectory() + "/.config/ns-dev"])
}

@Test func withoutAFolderNothingIsExported() {
    var exported: [String: String] = [:]

    NsConfigFolder.export(nil) { exported[$0] = $1 }

    #expect(exported.isEmpty)
}

@Test func aFreeTerminalGetsTheFolderTheAppExported() {
    #expect(NsConfigFolder.passedOn(["NS_CONFIG_DIR": "/x/ns-dev", "PATH": "/bin"]) == ["NS_CONFIG_DIR=/x/ns-dev"])
    #expect(NsConfigFolder.passedOn(["PATH": "/bin"]).isEmpty)
}
