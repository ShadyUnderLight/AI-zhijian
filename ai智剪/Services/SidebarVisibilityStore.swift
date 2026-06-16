import Foundation
import SwiftUI

// MARK: - SidebarVisibilityStore

/// 管理侧边栏各功能项的显隐状态。
///
/// ## 类型契约 (Type Contracts)
/// - `isVisible(tab)` ⇔ `!hiddenTabs.contains(tab.rawValue)`
/// - `setHidden(tab, true)` ⇒ `hiddenTabs` 包含 `tab.rawValue`
/// - `setHidden(tab, false)` ⇒ `hiddenTabs` 不包含 `tab.rawValue`
/// - `toggle(tab)` ⇒ `hiddenTabs` 含/不含 翻转
/// - `resetAll()` ⇒ `hiddenTabs` 为空集
/// - `hideAll()` ⇒ `hiddenTabs` 包含所有 `isPinnable == true` 的 tab
/// - `save()` ⇒ `UserDefaults["sidebar_hidden_tabs"]` == JSON 编码的 `[String]`
/// - `load()` ⇒ 从 `UserDefaults` 恢复；损坏/空数据 ⇒ `hiddenTabs = []`
///
/// ## 不变量
/// - `hiddenTabs` 中所有 rawValue 均为 `SidebarTab.allTabs` 中的有效值
/// - 默认状态：全部可见（空集）
///
/// ## 线程安全
/// - `@Published var hiddenTabs` 只能在 `@MainActor` 上下文中访问
/// - `save()` / `load()` 同步操作 UserDefaults，在 main actor 上安全调用
@MainActor
final class SidebarVisibilityStore: ObservableObject {
    // MARK: - Published State

    /// 当前被隐藏的 tab rawValue 集合。
    /// 空集表示全部可见。
    @Published private(set) var hiddenTabs: Set<String> = []

    // MARK: - Constants

    private let defaultsKey = "sidebar_hidden_tabs"

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Public API

    /// 判断指定 tab 是否可见。
    /// - Contract: 返回 `true` 当且仅当 `tab.rawValue` 不在 `hiddenTabs` 中。
    func isVisible(_ tab: SidebarTab) -> Bool {
        !hiddenTabs.contains(tab.rawValue)
    }

    /// 设置指定 tab 的显隐状态并持久化。
    /// - Contract: `hidden = true` ⇒ `hiddenTabs` 包含 `tab.rawValue`。
    /// - Contract: `hidden = false` ⇒ `hiddenTabs` 不包含 `tab.rawValue`。
    func setHidden(_ tab: SidebarTab, _ hidden: Bool) {
        if hidden {
            hiddenTabs.insert(tab.rawValue)
        } else {
            hiddenTabs.remove(tab.rawValue)
        }
        save()
    }

    /// 翻转指定 tab 的显隐状态并持久化。
    /// - Contract: 若 `isVisible(tab)` 为 `true` 变为 `false`，反之亦然。
    func toggle(_ tab: SidebarTab) {
        if hiddenTabs.contains(tab.rawValue) {
            hiddenTabs.remove(tab.rawValue)
        } else {
            hiddenTabs.insert(tab.rawValue)
        }
        save()
    }

    /// 恢复全部 tab 为可见状态。
    /// - Contract: `hiddenTabs` 变为空集。
    func resetAll() {
        hiddenTabs = []
        save()
    }

    /// 从给定数组中过滤出所有可见的 tab。
    /// - Contract: 返回 `tabs.filter { isVisible($0) }`。
    func filterVisible(_ tabs: [SidebarTab]) -> [SidebarTab] {
        tabs.filter { isVisible($0) }
    }

    /// 隐藏所有可隐藏的 tab（即 `isPinnable == true` 的 tab）。
    /// - Contract: `hiddenTabs` 包含所有 `isPinnable == true` 的 tab rawValue。
    func hideAll() {
        for tab in SidebarTab.allTabs where tab.isPinnable {
            hiddenTabs.insert(tab.rawValue)
        }
        save()
    }

    // MARK: - Persistence

    /// 将当前 hiddenTabs 持久化到 UserDefaults。
    /// 格式：JSON 编码的 `[String]` 数组。
    private func save() {
        guard let data = try? JSONEncoder().encode(Array(hiddenTabs)) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// 从 UserDefaults 恢复 hiddenTabs 状态。
    /// 损坏或无效数据 ⇒ `hiddenTabs = []`（全部可见的降级策略）。
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            hiddenTabs = []
            return
        }
        hiddenTabs = Set(array)
    }
}
