//
//  PluginStateManager.swift
//  TrollFools
//
//  Created by User on 2024/11/20.
//

import Foundation
import Combine
import SwiftUI

final class PluginStateManager: ObservableObject {
    // 存储结构：[插件文件名: 是否应该开启]
    @Published var pluginStates: [String: Bool] {
        didSet {
            storage.wrappedValue = pluginStates
        }
    }

    private var storage: CodableStorage<[String: Bool]>

    init(appId: String) {
        // 使用 AppID 隔离不同 App 的配置
        let initialStorage = CodableStorage<[String: Bool]>(key: "PluginStates-\(appId)", defaultValue: [:])
        self.storage = initialStorage
        self.pluginStates = initialStorage.wrappedValue
    }

    // 记录用户操作
    func setEnabled(_ isEnabled: Bool, forPlugin filename: String) {
        pluginStates[filename] = isEnabled
    }

    // 查询某插件是否应该开启（默认为 false，即如果不曾记录过，视为不开启）
    func shouldEnable(_ filename: String) -> Bool {
        return pluginStates[filename] ?? false
    }
}
