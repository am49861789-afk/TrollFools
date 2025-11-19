//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit

// 1. 简单的信箱服务，用来暂存桌面的跳转请求
class ShortcutService: ObservableObject {
    static let shared = ShortcutService()
    @Published var pendingID: String? = nil
}

// 2. AppDelegate：负责接收系统指令
class AppDelegate: NSObject, UIApplicationDelegate {
    // 情况A：App 在后台
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if handleShortcut(shortcutItem) {
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    // 情况B：App 冷启动
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            _ = handleShortcut(shortcutItem)
            return false
        }
        return true
    }

    // 统一处理：把 ID 存进信箱，不发通知，防止丢失
    private func handleShortcut(_ item: UIApplicationShortcutItem) -> Bool {
        if item.type == "wiki.qaq.TrollFools.openManagedApp",
           let bid = item.userInfo?["targetBid"] as? String {
            print("TrollFools: Shortcut received for \(bid)")
            ShortcutService.shared.pendingID = bid
            return true
        }
        return false
    }
}

@main
struct TrollFoolsApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 提升 model 为 StateObject，保证生命周期
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
