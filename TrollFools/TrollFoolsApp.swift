//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit // 新增引用

// 1. 定义通知名称
extension Notification.Name {
    static let tfEnableAllPlugins = Notification.Name("TFEnableAllPlugins")
}

// 2. 创建 AppDelegate 处理快捷方式
class AppDelegate: NSObject, UIApplicationDelegate {
    // 处理后台唤醒时的快捷操作
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "wiki.qaq.TrollFools.enableAll" {
            // 延迟发送通知，确保 UI 已经加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .tfEnableAllPlugins, object: nil)
            }
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    // 处理冷启动时的快捷操作
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           shortcutItem.type == "wiki.qaq.TrollFools.enableAll" {
            // 同样延迟发送通知
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .tfEnableAllPlugins, object: nil)
            }
            return false // 返回 false 告诉系统我们已经处理了 shortcutItem
        }
        return true
    }
}

@main
struct TrollFoolsApp: SwiftUI.App {
    // 3. 接入 AppDelegate
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
