//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import OrderedCollections
import SwiftUI
import SwiftUIIntrospect

typealias Scope = AppListModel.Scope

struct AppListView: View {
    let isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad

    @StateObject var searchViewModel = AppListSearchModel()
    @EnvironmentObject var appList: AppListModel
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // [新增] 控制跳转
        @State private var shortcutTargetApp: App?
        @State private var isShortcutActive: Bool = false
        // [新增] 轮询定时器
        let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    @State var selectorOpenedURL: URLIdentifiable? = nil
    @State var selectedIndex: String? = nil
    
    @State private var isEnableAllPluginsAlertPresented = false

    @State var isWarningPresented = false
    @State var temporaryOpenedURL: URLIdentifiable? = nil

    @State var latestVersionString: String?
    @State private var isUnsupportedSheetPresented = false

    @AppStorage("isAdvertisementHiddenV2")
    var isAdvertisementHidden: Bool = false

    @AppStorage("isWarningHidden")
    var isWarningHidden: Bool = false

    var shouldShowAdvertisement: Bool {
        return false
    }

    var appString: String {
        let appNameString = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TrollFools"
        let appVersionString = String(
            format: "v%@ (%@)",
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        )

        let appStringFormat = """
        %@ %@
        %@ © 2024-%d %@
        """

        return String(
            format: appStringFormat,
            appNameString, appVersionString,
            NSLocalizedString("Copyright", comment: ""),
            Calendar.current.component(.year, from: Date()),
            NSLocalizedString("Lessica, huami1314, iosdump and other contributors", comment: "")
        )
    }

    var  body:  some  View {
        ZStack {
            if #available (iOS 15, *) {
                content
                .alert(
                    NSLocalizedString("Notice", comment: ""),
                    isPresented: $isWarningPresented,
                    presenting: temporaryOpenedURL
                ) { result  in
                    Button {
                        selectorOpenedURL = result
                    } label: {
                        Text(NSLocalizedString("Continue", comment: ""))
                    }
                    Button(role: .destructive) {
                        selectorOpenedURL = result
                        isWarningHidden = true
                    } label: {
                        Text(NSLocalizedString("Continue and Don’t Show Again", comment: ""))
                    }
                    Button(role: .cancel) {
                        temporaryOpenedURL = nil
                        isWarningPresented = false
                    } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    Text(OptionView.warningMessage([$0.url]))
                }
        } else {
            content
        }
            if appList.isProcessingAllPlugins {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 15) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text(NSLocalizedString("Enabling Plug-Ins...", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(25)
                .background(Color.black.opacity(0.75))
                .cornerRadius(15)
                .shadow(radius: 10)
                .transition(.opacity)
            }
         }
        .animation(.easeOut, value: appList.isProcessingAllPlugins)
     }


    var content: some View {
        styledNavigationView
            .animation(.easeOut, value: appList.activeScopeApps.keys)
            .sheet(item: $selectorOpenedURL) { urlWrapper in
                AppListView()
                    .environmentObject(AppListModel(selectorURL: urlWrapper.url))
            }
            .onOpenURL { url in
                let ext = url.pathExtension.lowercased()
                guard url.isFileURL,
                      (ext == "dylib" || ext == "deb" || ext == "zip")
                else {
                    return
                }
                let urlIdent = URLIdentifiable(url: preprocessURL(url))
                if !isWarningHidden && ext == "deb" {
                    temporaryOpenedURL = urlIdent
                    isWarningPresented = true
                } else {
                    selectorOpenedURL = urlIdent
                }
            }
        // [新增] 轮询信箱
                .onReceive(timer) { _ in
                    attemptShortcutJump()
                }
            .onAppear {
                if Double.random(in: 0 ..< 1) < 0.1 {
                    isAdvertisementHidden = false
                }
            }
            .alert(isPresented: $isEnableAllPluginsAlertPresented) {
                Alert(
                    title: Text(NSLocalizedString("Enable All Disabled Plug-Ins", comment: "")),
                    message: Text(NSLocalizedString("This will enable all disabled plug-ins across all applications. This action may take some time.", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Confirm", comment: ""))) {
                        appList.isProcessingAllPlugins = true 
                        appList.enableAllDisabledPlugins {
                            appList.isProcessingAllPlugins = false
                            appList.reload()
                        }
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: "")))
                )
            }
                /*
                CheckUpdateManager.shared.checkUpdateIfNeeded { latestVersion, _ in
                    DispatchQueue.main.async {
                        withAnimation {
                            latestVersionString = latestVersion?.tagName
                        }
                    }
                }
                 */
    }
    
    // [新增] 核心跳转函数 (死缠烂打模式)
        private func attemptShortcutJump() {
            // 1. 没信件就返回
            guard let bid = ShortcutService.shared.pendingID else { return }
            
            // 2. 已经在跳转中就返回
            guard !isShortcutActive else { return }

            print("[TrollFools] Polling for: \(bid)")

            // 3. 尝试从列表找
            var foundApp: App? = nil
            for (_, apps) in appList.activeScopeApps {
                if let target = apps.first(where: { $0.bid == bid }) {
                    foundApp = target
                    break
                }
            }
            
            // 4. 【兜底】列表没加载完？直接用系统 API 构造一个！
            if foundApp == nil {
                if let proxy = LSApplicationProxy(forIdentifier: bid) {
                    foundApp = App(
                        bid: bid,
                        name: proxy.localizedName() ?? bid,
                        type: proxy.applicationType() ?? "User",
                        teamID: proxy.teamID() ?? "",
                        url: proxy.bundleURL()
                    )
                    foundApp?.appList = appList // 注入依赖
                    print("[TrollFools] Created fallback app object")
                }
            }
            
            // 5. 只有真正找到了对象，才执行跳转并销毁信件
            if let app = foundApp {
                print("[TrollFools] Target found! Jumping...")
                
                // 任务完成，销毁信件
                ShortcutService.shared.pendingID = nil
                
                // 执行跳转
                DispatchQueue.main.async {
                    self.shortcutTargetApp = app
                    self.isShortcutActive = true
                }
            }
            // 如果没找到，这里什么都不做。pendingID 还在，0.5秒后 timer 会再次调用这个函数重试。
        }

    var styledNavigationView: some View {
        Group {
            if isPad {
                navigationView
                    .navigationViewStyle(.automatic)
            } else {
                navigationView
                    .navigationViewStyle(.stack)
            }
        }
    }

    var navigationView: some View {
        NavigationView {
            ScrollViewReader { reader in
                ZStack {
                    
                    // [新增] 隐形跳转通道
                                NavigationLink(isActive: $isShortcutActive) {
                                    if let app = shortcutTargetApp {
                                        OptionView(app) // 跳转到管理页
                                    }
                                } label: {
                                    EmptyView()
                                }
                    
                    refreshableListView

                    if verticalSizeClass == .regular && appList.activeScopeApps.keys.count > 1 {
                        IndexableScroller(
                            indexes: appList.activeScopeApps.keys.elements,
                            currentIndex: $selectedIndex
                        )
                        .accessibilityHidden(true)
                    }
                }
                .onChange(of: selectedIndex) { index in
                    if let index {
                        reader.scrollTo("AppSection-\(index)", anchor: .center)
                    }
                }
            }

            // Detail view shown when nothing has been selected
            if !appList.isSelectorMode {
                PlaceholderView()
            }
        }
        
        .sheet(isPresented: $isUnsupportedSheetPresented) {
               UnsupportedAppListView(unsupportedApps: appList.unsupportedApps, isPresented: $isUnsupportedSheetPresented)
        }
    }

    var refreshableListView: some View {
        Group {
            if #available(iOS 15, *) {
                searchableListView
                    .refreshable {
                        appList.reload()
                    }
            } else {
                searchableListView
                    .introspect(.list, on: .iOS(.v14)) { tableView in
                        if tableView.refreshControl == nil {
                            tableView.refreshControl = {
                                let refreshControl = UIRefreshControl()
                                refreshControl.addAction(UIAction { action in
                                    appList.reload()
                                    if let control = action.sender as? UIRefreshControl {
                                        control.endRefreshing()
                                    }
                                }, for: .valueChanged)
                                return refreshControl
                            }()
                        }
                    }
            }
        }
    }

    var searchableListView: some View {
        listView
            .onChange(of: appList.showPatchedOnly) { showPatchedOnly in
                if let searchBar = searchViewModel.searchController?.searchBar {
                    reloadSearchBarPlaceholder(searchBar, showPatchedOnly: showPatchedOnly)
                }
            }
            .onReceive(searchViewModel.$searchKeyword) {
                appList.filter.searchKeyword = $0
            }
            .onReceive(searchViewModel.$searchScopeIndex) {
                appList.activeScope = Scope(rawValue: $0) ?? .all
            }
            .introspect(.viewController, on: .iOS(.v14, .v15, .v16, .v17, .v18)) { viewController in
                if searchViewModel.searchController == nil {
                    viewController.navigationItem.hidesSearchBarWhenScrolling = true
                    viewController.navigationItem.searchController = {
                        let searchController = UISearchController(searchResultsController: nil)
                        searchController.searchResultsUpdater = searchViewModel
                        searchController.obscuresBackgroundDuringPresentation = false
                        searchController.hidesNavigationBarDuringPresentation = true
                        searchController.automaticallyShowsScopeBar = false
                        if #available(iOS 16, *) {
                            searchController.scopeBarActivation = .manual
                        }
                        setupSearchBar(searchController: searchController)
                        return searchController
                    }()
                    searchViewModel.searchController = viewController.navigationItem.searchController
                }
            }
    }

    var listView: some View {
        List {
            if AppListModel.hasTrollStore && appList.isRebuildNeeded {
                rebuildSection.transition(.opacity)
            }

            switch appList.activeScope {
            case .all:
                allAppGroup.transition(.opacity)
            case .user:
                userAppGroup.transition(.opacity)
            case .troll:
                trollAppGroup.transition(.opacity)
            case .system:
                systemAppGroup.transition(.opacity)
            }
        }
        .animation(.easeOut, value: combines(
            appList.isRebuildNeeded,
            appList.activeScope,
            appList.filter,
            appList.unsupportedCount,
            shouldShowAdvertisement
        ))
        .listStyle(.insetGrouped)
        .navigationTitle(appList.isSelectorMode ?
            NSLocalizedString("Select Application to Inject", comment: "") :
            NSLocalizedString("TrollFools", comment: "")
        )
        .navigationBarTitleDisplayMode(appList.isSelectorMode ? .inline : .automatic)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if  appList.isSelectorMode,  let  selectorURL = appList.selectorURL {
                    VStack {
                        Text(selectorURL.lastPathComponent).font(.headline)
                        Text(NSLocalizedString("Select Application to Inject", comment: "")).font(.caption)
                    }
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isEnableAllPluginsAlertPresented = true
                } label: {
                    Image(systemName: "play.circle")
                }
                .disabled(appList.isProcessingAllPlugins)
                .accessibilityLabel(NSLocalizedString("Enable All Disabled Plug-Ins", comment: ""))

                Button {
                    appList.showPatchedOnly.toggle()
                } label: {
                    if #available (iOS 15, *) {
                        Image(systemName: appList.showPatchedOnly
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                    }  else  {
                        Image(systemName: appList.showPatchedOnly
                        ? "eject.circle.fill"
                        : "eject.circle")
                    }
                }
                .accessibilityLabel(NSLocalizedString("Show Patched Only", comment: ""))
            }
        }
    }

    var allAppGroup: some View {
        Group {
            if latestVersionString != nil {
                upgradeSection
            }
            else if !appList.filter.isSearching && !appList.showPatchedOnly && !appList.isRebuildNeeded && appList.unsupportedCount > 0 {
                unsupportedSection
            }

            
            //if #available(iOS 15, *) {
              //  if shouldShowAdvertisement {
                 //   advertisementSection
             //   }
          //  }
             

            appSections
        }
    }

    var userAppGroup: some View {
        Group {
            if !appList.filter.isSearching && !appList.showPatchedOnly && !appList.isRebuildNeeded && appList.unsupportedCount > 0 {
                Section {
                } footer: {
                    Button {
                        isUnsupportedSheetPresented = true
                    } label: {
                        paddedHeaderFooterText(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
                    }
                }
            }

            appSections
        }
    }

    var trollAppGroup: some View {
        Group {
            appSections
        }
    }

    var systemAppGroup: some View {
        Group {
            if !appList.filter.isSearching && !appList.showPatchedOnly && !appList.isRebuildNeeded {
                Section {
                } footer: {
                    paddedHeaderFooterText(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                }
            }

            appSections
        }
    }

    var appSections: some View {
        Group {
            if !appList.activeScopeApps.isEmpty {
                ForEach(Array(appList.activeScopeApps.keys), id: \.self) { sectionKey in
                    Section {
                        ForEach(appList.activeScopeApps[sectionKey] ?? [], id: \.id) { app in
                            NavigationLink {
                                if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                                    InjectView(app, urlList: [selectorURL])
                                } else {
                                    OptionView(app)
                                }
                            } label: {
                                if #available(iOS 16, *) {
                                    AppListCell(app: app)
                                } else {
                                    AppListCell(app: app)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    } header: {
                        paddedHeaderFooterText(sectionKey == selectedIndex ? "→ \(sectionKey)" : sectionKey)
                    } footer: {
                        if sectionKey == appList.activeScopeApps.keys.last {
                            footer
                        }
                    }
                    .id("AppSection-\(sectionKey)")
                }
            } else {
                Section {
                } header: {
                    paddedHeaderFooterText(NSLocalizedString("No Applications", comment: ""))
                        .textCase(.none)
                } footer: {
                    footer
                }
            }
        }
    }

    var rebuildSection: some View {
        Section {
            Button {
                appList.rebuildIconCache()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Rebuild Icon Cache", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(NSLocalizedString("You need to rebuild the icon cache in TrollStore to apply changes.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "timelapse")
                        .font(.title)
                        .foregroundColor(.accentColor)
                }
                .padding(.vertical, 4)
            }
        }
    }

    var upgradeSection: some View {
        Section {
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    CheckUpdateManager.shared.executeUpgrade()
                } label: {
                    Text(String(format: NSLocalizedString("New version %@ available!", comment: ""), latestVersionString ?? "(null)"))
                        .font(.footnote)
                }

                Text(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
                    .font(.footnote)
            }
        }
        .textCase(.none)
        .transition(.opacity)
    }

    var unsupportedSection: some View {
        Section {
        } footer: {
            Button {
                isUnsupportedSheetPresented = true
            } label: {
                paddedHeaderFooterText(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
            }
        }
        .textCase(.none)
        .transition(.opacity)
    }

    @available(iOS 15.0, *)
    var advertisementSection: some View {
        Section {
            Button {
                UIApplication.shared.open(App.advertisementApp.url)
            } label: {
                if #available(iOS 16, *) {
                    AppListCell(app: App.advertisementApp)
                } else {
                    AppListCell(app: App.advertisementApp)
                        .padding(.vertical, 4)
                }
            }
            .foregroundColor(.primary)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    isAdvertisementHidden = true
                } label: {
                    Label(NSLocalizedString("Hide", comment: ""), systemImage: "eye.slash")
                }
                .tint(.red)
            }
        } header: {
            paddedHeaderFooterText(NSLocalizedString("Advertisement", comment: ""))
        } footer: {
            paddedHeaderFooterText(NSLocalizedString("Buy our paid products to support us if you like TrollFools!", comment: ""))
        }
    }

    var footer: some View {
        Group {
            if !appList.isSelectorMode && !appList.filter.isSearching {
                if #available(iOS 16, *) {
                    footerContent
                        .padding(.top, 8)
                } else if #available(iOS 15, *) {
                    footerContent
                        .padding(.top, 2)
                } else {
                    footerContent
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 16)
    }

    var footerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appString)
                .font(.footnote)

            Button {
                UIApplication.shared.open(URL(string: "https://github.com/Lessica/TrollFools")!)
            } label: {
                Text(NSLocalizedString("Source Code", comment: ""))
                    .font(.footnote)
            }
        }
    }

    private func preprocessURL(_ url: URL) -> URL {
        let isInbox = url.path.contains("/Documents/Inbox/")
        guard isInbox else {
            return url
        }
        let fileNameNoExt = url.deletingPathExtension().lastPathComponent
        let fileNameComps = fileNameNoExt.components(separatedBy: CharacterSet(charactersIn: "._- "))
        guard let lastComp = fileNameComps.last, fileNameComps.count > 1, lastComp.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return url
        }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(String(fileNameNoExt.prefix(fileNameNoExt.count - lastComp.count - 1)))
            .appendingPathExtension(url.pathExtension)
        do {
            try? FileManager.default.removeItem(at: newURL)
            try FileManager.default.copyItem(at: url, to: newURL)
            return newURL
        } catch {
            return url
        }
    }

    private func setupSearchBar(searchController: UISearchController) {
        if let searchBarDelegate = searchController.searchBar.delegate, (searchBarDelegate as? NSObject) != searchViewModel {
            searchViewModel.forwardSearchBarDelegate = searchBarDelegate
        }

        searchController.searchBar.delegate = searchViewModel
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = Scope.allCases.map { $0.localizedShortName }
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no

        reloadSearchBarPlaceholder(searchController.searchBar, showPatchedOnly: appList.showPatchedOnly)
    }

    private func reloadSearchBarPlaceholder(_ searchBar: UISearchBar, showPatchedOnly: Bool) {
        searchBar.placeholder = (showPatchedOnly
            ? NSLocalizedString("Search Patched…", comment: "")
            : NSLocalizedString("Search…", comment: ""))
    }

    @ViewBuilder
    private func paddedHeaderFooterText(_ content: String) -> some View {
        if #available(iOS 15, *) {
            Text(content)
                .font(.footnote)
        } else {
            Text(content)
                .font(.footnote)
                .padding(.horizontal, 16)
        }
    }
}

struct URLIdentifiable: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
