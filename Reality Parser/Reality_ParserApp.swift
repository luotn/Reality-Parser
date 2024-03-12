//
//  Reality_ParserApp.swift
//  Reality Parser
//
//  Created by 罗天宁 on 25/04/2022.
//

import SwiftUI

@main
struct Reality_ParserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(width: 450, height: 500)
        }
        .commands() {
            CommandGroup(before: .appVisibility) {
                Button(String(localized: "Change Language")) {
                    print("Changing language...")
                    ContentView().changeLanguage()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
