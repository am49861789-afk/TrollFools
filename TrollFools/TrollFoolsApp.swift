//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit

// 1. 信箱服务：存储待跳转的 ID
class ShortcutService: ObservableObject {
    static let shared = ShortcutService()
    @Published var pendingID: String? = nil
}

// 2. SceneDelegate：核心处理类
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    // [场景生命周期] App 冷启动 (彻底杀后台后打开)
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 1. 检查是否通过 3D Touch 菜单启动
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcut(shortcutItem)
        }
        
        // 2. 检查是否通过 URL Scheme 启动
        if let urlContext = connectionOptions.urlContexts.first {
            handleURL(urlContext.url)
        }
    }

    // [场景生命周期] App 后台唤醒 (处理 3D Touch)
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcut(shortcutItem)
        completionHandler(true)
    }
    
    // [场景生命周期] App 后台唤醒 (处理 URL Scheme)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleURL(url)
        }
    }

    // --- 逻辑处理 ---

    // 处理桌面快捷菜单
    private func handleShortcut(_ item: UIApplicationShortcutItem) {
        if item.type == "wiki.qaq.TrollFools.openManagedApp",
           let bid = item.userInfo?["targetBid"] as? String {
            print("[TrollFools] SceneDelegate shortcut: \(bid)")
            ShortcutService.shared.pendingID = bid
        }
    }
    
    // 处理 URL 跳转 (trollfools://open?bid=xxx)
    private func handleURL(_ url: URL) {
        print("[TrollFools] SceneDelegate URL: \(url.absoluteString)")
        
        if url.scheme == "trollfools" && url.host == "open" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            // 提取 bid 参数
            if let queryItems = components?.queryItems,
               let bid = queryItems.first(where: { $0.name == "bid" })?.value {
                print("[TrollFools] URL target bid: \(bid)")
                ShortcutService.shared.pendingID = bid
            }
                    }
                    
                    // 2. [新增] 处理一键启用全部插件
                    // 格式: trollfools://enable-all
                    if url.scheme == "trollfools" && url.host == "enable-all" {
                        print("[TrollFools] Received Enable All Plugins request via URL")
                        
                        // 发送通知，触发 TrollFoolsApp 里的 .onReceive 监听逻辑
                        // 延迟 0.5 秒确保 UI 加载完毕
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: .tfEnableAllPlugins, object: nil)
                        }
                    }
                }

// 3. AppDelegate：配置 SceneDelegate
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
