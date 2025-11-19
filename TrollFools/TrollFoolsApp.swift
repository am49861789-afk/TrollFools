//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit

// 1. 导航服务
class ShortcutNavigationService: ObservableObject {
    static let shared = ShortcutNavigationService()
    @Published var targetBundleID: String? = nil
}

// 2. AppDelegate 拦截快捷菜单
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
        if item.type == "wiki.qaq.TrollFools.openManagedApp",
           let bid = item.userInfo?["targetBid"] as? String {
            // 延迟 0.8 秒，给数据加载留出时间，虽然我们有了兜底机制，多一点缓冲更稳
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                ShortcutNavigationService.shared.targetBundleID = bid
            }
        }
    }
}

@main
struct TrollFoolsApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 关键修改：使用 @StateObject 保证 Model 不会因为视图刷新而丢失数据
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
