//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit

// 1. 信箱服务：用来暂存待处理的跳转 ID
class ShortcutService: ObservableObject {
    static let shared = ShortcutService()
    @Published var pendingID: String? = nil
}

// 2. SceneDelegate：这是 Scene 模式下接收快捷指令的唯一入口
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // 情况A：App 冷启动
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcut(shortcutItem)
        }
    }

    // 情况B：App 后台唤醒
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcut(shortcutItem)
        completionHandler(true)
    }

    // 统一处理：把 ID 存入信箱
    private func handleShortcut(_ item: UIApplicationShortcutItem) {
        if item.type == "wiki.qaq.TrollFools.openManagedApp",
           let bid = item.userInfo?["targetBid"] as? String {
            print("[TrollFools] SceneDelegate received shortcut for: \(bid)")
            ShortcutService.shared.pendingID = bid
        }
    }
}

// 3. AppDelegate：负责配置 SceneDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

@main
struct TrollFoolsApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 确保 Model 唯一且持久
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
