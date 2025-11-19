//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit

// MARK: - 1. 新增：全局状态管理器 (就像一个信箱)
class QuickActionService: ObservableObject {
    static let shared = QuickActionService()
    @Published var shouldEnableAllPlugIns: Bool = false
}

// MARK: - 2. 修改：AppDelegate 负责接收系统指令并存入信箱
class AppDelegate: NSObject, UIApplicationDelegate {
    // 处理后台唤醒
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcut(shortcutItem)
        completionHandler(true)
    }

    // 处理冷启动
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            handleShortcut(shortcutItem)
            return false
        }
        return true
    }

    private func handleShortcut(_ item: UIApplicationShortcutItem) {
        if item.type == "wiki.qaq.TrollFools.enableAll" {
            // 核心修改：不再发通知，而是直接修改状态变量
            // 无论 UI 什么时候准备好，这个变量都为 true，跑不掉
            DispatchQueue.main.async {
                QuickActionService.shared.shouldEnableAllPlugIns = true
            }
        }
    }
}

@main
struct TrollFoolsApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
                        .environmentObject(AppListModel())
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
