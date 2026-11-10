import Testing
import Foundation

@Test func theDebugAppIsNotTheRealApp() {
    #expect(Bundle.main.bundleIdentifier == "dev.brenosonda.Thalamus.dev")
    #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String == "Thalamus Dev")
}
