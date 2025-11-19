//
//  App.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import Foundation

final class App: Identifiable, Equatable, Hashable, ObservableObject {
    let bid: String
    let name: String
    let latinName: String
    let type: String
    let teamID: String
    let url: URL
    let version: String?
    let isAdvertisement: Bool

    @Published var isDetached: Bool
    @Published var isAllowedToAttachOrDetach: Bool
    @Published var isInjected: Bool
    @Published var hasPersistedAssets: Bool

    lazy var icon: UIImage? = UIImage._applicationIconImage(forBundleIdentifier: bid, format: 0, scale: 3.0)
    var alternateIcon: UIImage?

    lazy var isUser: Bool = type == "User"
    lazy var isSystem: Bool = !isUser
    lazy var isFromApple: Bool = bid.hasPrefix("com.apple.")
    lazy var isFromTroll: Bool = isSystem && !isFromApple
    lazy var isRemovable: Bool = url.path.contains("/var/containers/Bundle/Application/")

    weak var appList: AppListModel?
    private var cancellables: Set<AnyCancellable> = []
    private static let reloadSubject = PassthroughSubject<String, Never>()

    init(
        bid: String,
        name: String,
        type: String,
        teamID: String,
        url: URL,
        version: String? = nil,
        alternateIcon: UIImage? = nil,
        isAdvertisement: Bool = false
    ) {
        self.bid = bid
        self.name = name
        self.type = type
        self.teamID = teamID
        self.url = url
        self.version = version
        self.isDetached = InjectorV3.main.isMetadataDetachedInBundle(url)
        self.isAllowedToAttachOrDetach = type == "User" && InjectorV3.main.isAllowedToAttachOrDetachMetadataInBundle(url)
        self.isInjected = InjectorV3.main.checkIsInjectedAppBundle(url)
        self.hasPersistedAssets = InjectorV3.main.hasPersistedAssets(bid: bid)
        self.alternateIcon = alternateIcon
        self.isAdvertisement = isAdvertisement
        self.latinName = name
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)?
            .components(separatedBy: .whitespaces)
            .joined() ?? ""
        Self.reloadSubject
            .filter { $0 == bid }
            .sink { [weak self] _ in
                self?._reload()
            }
            .store(in: &cancellables)
    }

    func reload() {
        Self.reloadSubject.send(bid)
    }

    private func _reload() {
        reloadDetachedStatus()
        reloadInjectedStatus()
    }

    private func reloadDetachedStatus() {
        self.isDetached = InjectorV3.main.isMetadataDetachedInBundle(url)
        self.isAllowedToAttachOrDetach = isUser && InjectorV3.main.isAllowedToAttachOrDetachMetadataInBundle(url)
    }

    private func reloadInjectedStatus() {
        self.isInjected = InjectorV3.main.checkIsInjectedAppBundle(url)
        self.hasPersistedAssets = InjectorV3.main.hasPersistedAssets(bid: bid)
    }
    
    var id: String { bid }

    static func == (lhs: App, rhs: App) -> Bool {
        lhs.bid == rhs.bid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bid)
    }
}
// --- 请添加到 App.swift 最底部 ---

extension App {
    // 检查当前 App 是否已经在桌面菜单中
    var isPinnedToHome: Bool {
        let pinnedIDs = UserDefaults.standard.stringArray(forKey: "pinned_shortcut_ids") ?? []
        return pinnedIDs.contains(bid)
    }

    // 切换状态：添加或移除
    func toggleHomeShortcut() {
        var pinnedIDs = UserDefaults.standard.stringArray(forKey: "pinned_shortcut_ids") ?? []
        
        if isPinnedToHome {
            pinnedIDs.removeAll { $0 == bid }
        } else {
            // 限制最多添加 3 个，防止挤占系统菜单
            if pinnedIDs.count >= 3 { return }
            pinnedIDs.append(bid)
        }
        
        UserDefaults.standard.set(pinnedIDs, forKey: "pinned_shortcut_ids")
        updateApplicationShortcuts(with: pinnedIDs)
        
        // 通知界面刷新状态
        objectWillChange.send()
    }

    // 更新 iOS 系统的桌面快捷菜单
    private func updateApplicationShortcuts(with ids: [String]) {
        var shortcuts: [UIApplicationShortcutItem] = []
        
        for id in ids {
            // 尝试获取应用名称，如果获取失败则显示 Bundle ID
            let appName = LSApplicationProxy(forIdentifier: id)?.localizedName() ?? id
            
            let icon = UIApplicationShortcutIcon(systemImageName: "gear") // 使用齿轮图标
            let item = UIApplicationShortcutItem(
                type: "wiki.qaq.TrollFools.openManagedApp", // 唯一的标识符
                localizedTitle: appName,
                localizedSubtitle: nil,
                icon: icon,
                userInfo: ["targetBid": id as NSSecureCoding] // 关键：把 BundleID 存进去
            )
            shortcuts.append(item)
        }
        
        UIApplication.shared.shortcutItems = shortcuts
    }
}
