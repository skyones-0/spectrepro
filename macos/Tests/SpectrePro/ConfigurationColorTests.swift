import SwiftUI
import Testing
@testable import SpectrePro

@Suite
struct ConfigurationColorTests {
    @Test func supportsEveryDirectColorControl() {
        for key in [
            "background",
            "foreground",
            "selection-foreground",
            "selection-background",
            "cursor-color",
            "cursor-text",
            "unfocused-split-fill",
            "split-divider-color",
            "search-foreground",
            "search-background",
            "search-selected-foreground",
            "search-selected-background",
            "window-titlebar-background",
            "window-titlebar-foreground",
            "bold-color",
            "macos-icon-ghost-color",
        ] {
            #expect(ConfigurationColor.supports(key))
        }
    }

    @Test func normalizesHexadecimalColors() {
        #expect(ConfigurationColor.string(ConfigurationColor.hex("#1a2b3c")) == "#1A2B3C")
        #expect(ConfigurationColor.string(ConfigurationColor.hex("1A2B3C")) == "#1A2B3C")
    }
}
