//
//  PlugInCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import QuickLook
import SwiftUI

private let gDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct PlugInCell: View {
    @EnvironmentObject var ejectList: EjectListModel
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @Binding var quickLookExport: URL?
    
    @EnvironmentObject var renameManager: RenameManager
    @State private var isRenameSheetPresented = false
    
    @State var isEnabled: Bool = false

    let plugIn: InjectedPlugIn

    init (_ plugIn: InjectedPlugIn, quickLookExport: Binding<URL?>) {
           self.plugIn = plugIn
           self._quickLookExport = quickLookExport
       }
    
    private var displayName: String {
        renameManager.plugInRenames[plugIn.url.lastPathComponent] ?? plugIn.url.lastPathComponent
    }

    @available(iOS 15, *)
    var highlightedName: AttributedString {
        let name = displayName
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: ejectList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    var iconName: String {
        let pathExt = plugIn.url.pathExtension.lowercased()
        if pathExt == "bundle" {
            return "archivebox"
        }
        if pathExt == "dylib" {
            return "bandage"
        }
        if pathExt == "framework" {
            return "shippingbox"
        }
        return "puzzlepiece"
    }

    var body: some View {
            // 判断：系统正在替换中 且 目标就是我自己
            if ejectList.isReplacing && ejectList.plugInToReplace == plugIn {
                // [新样式] 显示原有内容 + 菊花
                HStack {
                    labelContent // 复用原本的图标和文字
                    Spacer()
                    ProgressView() // 菊花代替开关
                        .padding(.trailing, 2) // 微调位置对齐
                }
                .padding(.vertical, 4) // 保持高度一致
                // 注意：这里不加 .contextMenu，替换时禁止操作
            } else {
                // [旧样式] 原有的开关
                Toggle(isOn: $isEnabled) {
                    labelContent
                }
                .onAppear {
                    isEnabled = plugIn.isEnabled
                }
                .onChange(of: isEnabled) { value in
                    ejectList.togglePlugIn(plugIn, isEnabled: value)
                }
                .contextMenu {
                    Button {
                        isRenameSheetPresented = true
                    } label: {
                        Label(NSLocalizedString("Rename", comment: ""), systemImage: "pencil")
                    }
                    Button {
                        ejectList.plugInToReplace = plugIn
                    } label: {
                        Label(NSLocalizedString("Replace", comment: ""), systemImage: "arrow.triangle.2.circlepath")
                    }
                    if #available(iOS 16.4, *) {
                        ShareLink(item: plugIn.url) {
                            Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            exportPlugIn()
                        } label: {
                            Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        openInFilza()
                    } label: {
                        if isFilzaInstalled {
                            Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
                        } else {
                            Label(NSLocalizedString("Filza (URL Scheme) Not Installed", comment: ""), systemImage: "xmark.octagon")
                        }
                    }
                    .disabled(!isFilzaInstalled)
                }
                .sheet(isPresented: $isRenameSheetPresented) {
                    RenameSheetView(isPresented: $isRenameSheetPresented, plugInFilename: plugIn.url.lastPathComponent, currentName: displayName)
                        .environmentObject(renameManager)
                }
            }
        }

        // [新增] 提取出来的标签内容 (图标+文字)，供上面复用
        var labelContent: some View {
            HStack(spacing: 12) {
                if verticalSizeClass == .compact {
                    Image(systemName: iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading) {
                    if #available(iOS 15, *) {
                        Text(highlightedName)
                            .font(.headline)
                            .lineLimit(2)
                    } else {
                        Text(displayName)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    Text(gDateFormatter.string(from: plugIn.createdAt))
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
        }
    
    private func exportPlugIn() {
        quickLookExport = plugIn.url
    }

    var isFilzaInstalled: Bool { ejectList.app.appList?.isFilzaInstalled ?? false }

    private func openInFilza() {
        ejectList.app.appList?.openInFilza(plugIn.url)
    }
    
    private struct RenameSheetView: View {
        @Binding var isPresented: Bool
        @EnvironmentObject var renameManager: RenameManager
        
        let plugInFilename: String
        
        let currentName: String
        
        @State private var newName: String = ""
        @State private var didAppear = false

        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text(NSLocalizedString("Custom Name", comment: ""))) {
                        TextField(NSLocalizedString("Enter new name", comment: ""), text: $newName)
                    Text(NSLocalizedString("Leave it empty to restore the original name.", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                .introspect(.textField, on: .iOS(.v14, .v15, .v16, .v17)) { textField in
                    if !didAppear {
                        textField.becomeFirstResponder()
                        didAppear = true
                    }
                }
                
                .navigationTitle(NSLocalizedString("Rename", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    newName = currentName
                }
                
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("Cancel", comment: "")) {
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("Save", comment: "")) {
                            if newName.trimmingCharacters(in: .whitespaces).isEmpty {
                                renameManager.plugInRenames.removeValue(forKey: plugInFilename)
                            } else {
                                renameManager.plugInRenames[plugInFilename] = newName
                            }
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}
