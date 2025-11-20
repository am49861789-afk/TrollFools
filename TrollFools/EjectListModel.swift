//
//  EjectListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import SwiftUI

final class EjectListModel: ObservableObject {
    let app: App
    private(set) var injectedPlugIns: [InjectedPlugIn] = []

    @Published var filter = FilterOptions()
    
    // [新增] 也是为了让 Model 知道有哪些重命名
        var plugInRenames: [String: String] = [:]
    
    // [新增] 全局替换状态，让 Cell 也能读取到
        @Published var isReplacing: Bool = false
    @Published var filteredPlugIns: [InjectedPlugIn] = []

    @Published var isOkToEnableAll = false
    @Published var isOkToDisableAll = false

    @Published var processingPlugIn: InjectedPlugIn?
    @Published var plugInToReplace: InjectedPlugIn?

    private var cancellables = Set<AnyCancellable>()

    init(_ app: App) {
        self.app = app
        reload()

        $filter
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.performFilter()
            }
            .store(in: &cancellables)
    }

    func reload() {
        var plugIns = [InjectedPlugIn]()
        plugIns += InjectorV3.main.injectedAssetURLsInBundle(app.url)
            .map { InjectedPlugIn(url: $0, isEnabled: true) }

        let enabledNames = plugIns.map { $0.url.lastPathComponent }
        plugIns += InjectorV3.main.persistedAssetURLs(bid: app.bid)
            .filter { !enabledNames.contains($0.lastPathComponent) }
            .map { InjectedPlugIn(url: $0, isEnabled: false) }

        injectedPlugIns = plugIns
            .sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }

        performFilter()
    }

    // [修改] 升级后的搜索逻辑：同时匹配“原文件名”和“自定义备注名”
        func performFilter() {
            var filteredPlugIns = injectedPlugIns
            if !filter.searchKeyword.isEmpty {
                filteredPlugIns = filteredPlugIns.filter { plugin in
                    let fileName = plugin.url.lastPathComponent
                    // 1. 检查原文件名
                    if fileName.localizedCaseInsensitiveContains(filter.searchKeyword) {
                        return true
                    }
                    // 2. 检查重命名后的名字 (如果有)
                    if let customName = plugInRenames[fileName],
                       customName.localizedCaseInsensitiveContains(filter.searchKeyword) {
                        return true
                    }
                    return false
                }
            }
            self.filteredPlugIns = filteredPlugIns
            isOkToEnableAll = filteredPlugIns.contains { !$0.isEnabled }
            isOkToDisableAll = filteredPlugIns.contains { $0.isEnabled }
        }

    func togglePlugIn(_ plugIn: InjectedPlugIn, isEnabled: Bool) {
        guard plugIn.isEnabled != isEnabled else {
            return
        }
        processingPlugIn = plugIn
    }
}
