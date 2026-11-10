import Testing
import Foundation

@Test func theDebugAppIsNotTheRealApp() {
    #expect(Bundle.main.bundleIdentifier == "gabrielpassos.Den.dev")
    #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String == "Den Dev")
}
