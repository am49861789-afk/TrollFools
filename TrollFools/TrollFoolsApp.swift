//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit

// 1. 信箱服务：只负责存取 ID
class ShortcutService: ObservableObject {
    static let shared = ShortcutService()
    @Published var pendingID: String? = nil
}

// 2. AppDelegate：收到系统指令 -> 存入信箱
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcut(shortcutItem)
        completionHandler(true)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            handleShortcut(shortcutItem)
            return false
        }
        return true
    }

    private func handleShortcut(_ item: UIApplicationShortcutItem) {
        // 核心逻辑：只存 ID，不做任何跳转尝试
        if item.type == "wiki.qaq.TrollFools.openManagedApp",
           let bid = item.userInfo?["targetBid"] as? String {
            print("[TrollFools] Received Shortcut ID: \(bid)")
            ShortcutService.shared.pendingID = bid
        }
    }
}

@main
struct TrollFoolsApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var model = AppListModel()
    @AppStorage("isDisclaimerHiddenV2")
    var isDisclaimerHidden: Bool = false

    init() {
        try? FileManager.default.removeItem(at: InjectorV3.temporaryRoot)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isDisclaimerHidden {
                    AppListView()
                        .environmentObject(model)
                        .transition(.opacity)
                } else {
                    DisclaimerView(isDisclaimerHidden: $isDisclaimerHidden)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isDisclaimerHidden)
        }
    }
}
