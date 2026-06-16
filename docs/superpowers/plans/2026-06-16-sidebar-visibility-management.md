# 侧边栏显隐管理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户可通过设置页开关控制侧边栏中每个功能项的显示/隐藏

**Architecture:** 新增 `SidebarVisibilityStore` (ObservableObject) 管理隐藏状态（Set<String> of hidden tab rawValues），持久化到 UserDefaults key `sidebar_hidden_tabs`（JSON 编码 [String]），通过环境对象注入。MainView 根据 Store 过滤各 Section 条目。SettingsView 新增分类 Switch 列表。

**Tech Stack:** Swift 6.0, SwiftUI, UserDefaults, XCTest

---

### Task 1: 创建 SidebarVisibilityStore + 单元测试

**Files:**
- Create: `ai智剪/Services/SidebarVisibilityStore.swift`
- Create: `ai智剪Tests/SidebarVisibilityStoreTests.swift`

**类型契约:**
- `hiddenTabs: Set<String>` — 被隐藏的 tab rawValue 集合。空集表示全部可见。
- 不变量：hiddenTabs 中所有元素都是 `SidebarTab.allTabs` 中的有效 rawValue。
- 默认值：空集（全部可见）。
- 持久化 key: `sidebar_hidden_tabs`，格式：JSON 编码的 `[String]`。
- 属性测试性质：
  - 初始状态 hiddenTabs 为空
  - 隐藏 → isVisible 返回 false
  - 显示 → isVisible 返回 true
  - toggle 两次回到原始状态
  - resetAll 清空隐藏集
  - 持久化 roundtrip 保持状态
  - Codable roundtrip

**SidebarVisibilityStore API:**
```swift
// 类型契约 (Type Contract):
// isVisible(tab) ⇔ !hiddenTabs.contains(tab.rawValue)
// setHidden(tab, true) ⇒ hiddenTabs 包含 tab.rawValue
// setHidden(tab, false) ⇒ hiddenTabs 不包含 tab.rawValue
// toggle(tab) ⇒ hiddenTabs 含/不含 翻转
// resetAll() ⇒ hiddenTabs 为空
// save() ⇒ UserDefaults 写入当前状态
// load() ⇒ 从 UserDefaults 恢复状态
// Codable: JSON 编码/解码 roundtrip 保持 Set<String> 不变

final class SidebarVisibilityStore: ObservableObject {
    @Published private(set) var hiddenTabs: Set<String>
    private let defaultsKey = "sidebar_hidden_tabs"
    
    init() { /* load from UserDefaults */ }
    
    func isVisible(_ tab: SidebarTab) -> Bool    // Contract 1
    func setHidden(_ tab: SidebarTab, _ hidden: Bool)  // Contract 2, 3
    func toggle(_ tab: SidebarTab)               // Contract 4
    func resetAll()                               // Contract 5
    func hideAll()                                // 隐藏所有可隐藏项
    
    private func save()    // Contract 6
    private func load()    // Contract 7
}
```

- [ ] **Step 1: Write failing tests** — SidebarVisibilityStoreTests.swift 包含:

```swift
import XCTest
@testable import aiZhijian

final class SidebarVisibilityStoreTests: XCTestCase {
    private var sut: SidebarVisibilityStore!
    
    override func setUp() {
        super.setUp()
        // 清除 UserDefaults 确保测试隔离
        UserDefaults.standard.removeObject(forKey: "sidebar_hidden_tabs")
        sut = SidebarVisibilityStore()
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "sidebar_hidden_tabs")
        sut = nil
        super.tearDown()
    }
    
    // ——— 默认状态 ———
    func testDefaultAllTabsVisible() {
        // 初始状态：全部可见
        for tab in SidebarTab.allTabs {
            XCTAssertTrue(sut.isVisible(tab), "\(tab.rawValue) 默认应可见")
        }
    }
    
    // ——— 隐藏/显示 ———
    func testHideTabMakesItInvisible() {
        sut.setHidden(.imageGen, true)
        XCTAssertFalse(sut.isVisible(.imageGen))
    }
    
    func testShowTabMakesItVisible() {
        sut.setHidden(.imageGen, true)
        sut.setHidden(.imageGen, false)
        XCTAssertTrue(sut.isVisible(.imageGen))
    }
    
    func testHideTabDoesNotAffectOtherTabs() {
        sut.setHidden(.imageGen, true)
        XCTAssertFalse(sut.isVisible(.imageGen))
        XCTAssertTrue(sut.isVisible(.banana))
        XCTAssertTrue(sut.isVisible(.seedance))
        XCTAssertTrue(sut.isVisible(.dashboard))
    }
    
    // ——— Toggle ———
    func testToggleFlipsVisibility() {
        let initial = sut.isVisible(.wan)
        sut.toggle(.wan)
        XCTAssertEqual(sut.isVisible(.wan), !initial)
        sut.toggle(.wan)
        XCTAssertEqual(sut.isVisible(.wan), initial)
    }
    
    // ——— Reset ———
    func testResetAllShowsEverything() {
        sut.setHidden(.wan, true)
        sut.setHidden(.grok, true)
        sut.setHidden(.banana, true)
        sut.resetAll()
        for tab in SidebarTab.allTabs {
            XCTAssertTrue(sut.isVisible(tab))
        }
    }
    
    // ——— HideAll ———
    func testHideAllHidesPinnableTabs() {
        sut.hideAll()
        for tab in SidebarTab.allTabs {
            if tab.isPinnable {
                XCTAssertFalse(sut.isVisible(tab), "\(tab.rawValue) 应被隐藏")
            } else {
                XCTAssertTrue(sut.isVisible(tab), "不可置顶项 \(tab.rawValue) 不应被隐藏")
            }
        }
    }
    
    // ——— 持久化 ———
    func testPersistenceRoundTrip() {
        sut.setHidden(.seedance, true)
        sut.setHidden(.voiceGen, true)
        // 创建新实例模拟重新启动
        let newStore = SidebarVisibilityStore()
        XCTAssertFalse(newStore.isVisible(.seedance))
        XCTAssertFalse(newStore.isVisible(.voiceGen))
        XCTAssertTrue(newStore.isVisible(.dashboard))
    }
    
    // ——— Codable Roundtrip ———
    func testCodableRoundTrip() throws {
        sut.setHidden(.veo, true)
        sut.setHidden(.grok, true)
        let data = try JSONEncoder().encode(sut.hiddenTabs)
        let decoded = try JSONDecoder().decode(Set<String>.self, from: data)
        XCTAssertEqual(decoded, sut.hiddenTabs)
        XCTAssertTrue(decoded.contains("Veo 视频"))
        XCTAssertTrue(decoded.contains("Grok 视频"))
        XCTAssertFalse(decoded.contains("首页"))
    }
    
    // ——— 不变量：只存有效 tab rawValue ———
    func testOnlyValidTabRawValuesAreSaved() {
        sut.setHidden(.wan, true)
        sut.setHidden(.veo, true)
        // hiddenTabs 中的值应都在 SidebarTab.allTabs rawValues 中
        for rawValue in sut.hiddenTabs {
            XCTAssertTrue(SidebarTab.allTabs.contains(where: { $0.rawValue == rawValue }),
                         "\(rawValue) 不是有效的 SidebarTab rawValue")
        }
    }
    
    // ——— 脏数据容错 ———
    func testLoadHandlesCorruptedUserDefaults() {
        UserDefaults.standard.set("not an array".data(using: .utf8)!, forKey: "sidebar_hidden_tabs")
        let store = SidebarVisibilityStore()
        XCTAssertTrue(store.hiddenTabs.isEmpty, "损坏数据应恢复为默认状态")
        for tab in SidebarTab.allTabs {
            XCTAssertTrue(store.isVisible(tab))
        }
    }
    
    func testLoadHandlesInvalidJSON() {
        UserDefaults.standard.set(Data("garbage data".utf8), forKey: "sidebar_hidden_tabs")
        let store = SidebarVisibilityStore()
        XCTAssertTrue(store.hiddenTabs.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ai智剪 -destination 'platform=macOS' -only-testing:ai智剪Tests/SidebarVisibilityStoreTests 2>&1 | tail -30`
Expected: FAIL — class not found / method not found

- [ ] **Step 3: Write implementation** — SidebarVisibilityStore.swift

```swift
import Foundation
import SwiftUI

/// 管理侧边栏各功能项的显隐状态。
/// 默认全部可见。状态序列化为 JSON [String] 存储在 UserDefaults。
final class SidebarVisibilityStore: ObservableObject {
    // MARK: - Type Contracts
    //
    // 1. isVisible(tab) ⇔ !hiddenTabs.contains(tab.rawValue)
    // 2. setHidden(tab, true) ⇒ hiddenTabs 包含 tab.rawValue
    // 3. setHidden(tab, false) ⇒ hiddenTabs 不包含 tab.rawValue
    // 4. toggle(tab) ⇒ hiddenTabs 含/不含 翻转
    // 5. resetAll() ⇒ hiddenTabs 为空
    // 6. save() ⇒ UserDefaults["sidebar_hidden_tabs"] == JSON(hiddenTabs)
    // 7. load() 从 UserDefaults 恢复；损坏/空数据 ⇒ hiddenTabs = []
    
    @Published private(set) var hiddenTabs: Set<String> = []
    
    private let defaultsKey = "sidebar_hidden_tabs"
    
    init() {
        load()
    }
    
    /// - Contract: 返回 true 当且仅当 tab 不在 hiddenTabs 中
    func isVisible(_ tab: SidebarTab) -> Bool {
        !hiddenTabs.contains(tab.rawValue)
    }
    
    /// - Contract: 设置 tab 的显隐状态并持久化
    func setHidden(_ tab: SidebarTab, _ hidden: Bool) {
        if hidden {
            hiddenTabs.insert(tab.rawValue)
        } else {
            hiddenTabs.remove(tab.rawValue)
        }
        save()
    }
    
    /// - Contract: 翻转 tab 的显隐状态并持久化
    func toggle(_ tab: SidebarTab) {
        if hiddenTabs.contains(tab.rawValue) {
            hiddenTabs.remove(tab.rawValue)
        } else {
            hiddenTabs.insert(tab.rawValue)
        }
        save()
    }
    
    /// - Contract: 恢复全部 tab 可见
    func resetAll() {
        hiddenTabs = []
        save()
    }
    
    /// - Contract: 隐藏所有可置顶（即可隐藏）的 tab
    func hideAll() {
        for tab in SidebarTab.allTabs where tab.isPinnable {
            hiddenTabs.insert(tab.rawValue)
        }
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        guard let data = try? JSONEncoder().encode(Array(hiddenTabs)) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            hiddenTabs = []
            return
        }
        hiddenTabs = Set(array)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ai智剪 -destination 'platform=macOS' -only-testing:ai智剪Tests/SidebarVisibilityStoreTests 2>&1 | tail -30`
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add ai智剪/Services/SidebarVisibilityStore.swift ai智剪Tests/SidebarVisibilityStoreTests.swift
git commit -m "feat: add SidebarVisibilityStore with UserDefaults persistence"
```

---

### Task 2: MainView 侧边栏过滤逻辑 + 注入 Store

**Files:**
- Modify: `ai智剪/Views/MainView.swift`
- Test: `ai智剪Tests/SidebarVisibilityStoreTests.swift`（追加 MainView 过滤测试）

**设计分析:**
- MainView 需要 `@EnvironmentObject var sidebarVisibility: SidebarVisibilityStore`
- 每个 Section 构建 items 数组时过滤：`sectionItems.filter { sidebarVisibility.isVisible($0) }`
- 空 Section 自动隐藏
- 现有的 `visibleTabRawValues` （角色/权限过滤）保持优先，显隐过滤叠加在其上
- Pinned 区域也受显隐过滤影响（已经通过 `visibleTabRawValues` 间接处理，但需再叠加显隐过滤）
- 选中 tab 被隐藏后应自动跳转到首页

- [ ] **Step 1: Write MainView integration tests**

在 SidebarVisibilityStoreTests.swift 追加：

```swift
// MARK: - MainView Integration
    
func testMainViewHiddenTabDoesNotAppear() {
    // 创建一个 MainView 并注入 store
    // 隐藏某个 tab 后验证它不出现在侧边栏
    // 这是一个集成验证，确保 store 与 MainView 的联动正确
    let store = SidebarVisibilityStore()
    store.setHidden(.banana, true)
    // 验证 hiddenTabs 包含 banana
    XCTAssertTrue(store.hiddenTabs.contains("Banana 图片"))
    XCTAssertFalse(store.isVisible(.banana))
    XCTAssertTrue(store.isVisible(.imageGen))
}
```

- [ ] **Step 2: Run tests to verify they fail** — same command as Task 1 Step 2

- [ ] **Step 3: Implementation — MainView 改动**

改动点：

a) 在 `MainView` struct 增加 `@EnvironmentObject var sidebarVisibility: SidebarVisibilityStore`

b) 每个 Section 改为构建 visible items 数组 + 条件渲染：

```swift
private var imageItems: [SidebarTab] { [.imageGen, .banana].filter { sidebarVisibility.isVisible($0) } }
// ... 每个 section 对应一个 computed property

private var sectionData: [(String, [SidebarTab])] { ... }
```

或者直接在 body 中为每个 Section 做条件渲染：

```swift
Section("首页") {
    if sidebarVisibility.isVisible(.dashboard) {
        sidebarLabel(.dashboard)
    }
}
```

**推荐方案：** 为每个 section 定义 computed property 返回可见 items，然后用 `if !items.isEmpty { Section { ... } }` 包裹。

c) `visibleTabRawValues` 需要叠加显隐过滤：

```swift
private var visibleTabRawValues: Set<String> {
    var values = Set(SidebarTab.allTabs.map(\.rawValue))
    // 现有角色/权限过滤...
    
    // 显隐过滤
    for rawValue in sidebarVisibility.hiddenTabs {
        values.remove(rawValue)
    }
    return values
}
```

d) 当选中 tab 被隐藏时自动跳转：

在 `.onChange(of: sidebarVisibility.hiddenTabs)` 中添加：

```swift
.onChange(of: sidebarVisibility.hiddenTabs) { _, newHidden in
    if newHidden.contains(selectedTab.rawValue) {
        selectedTab = .dashboard
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ai智剪 -destination 'platform=macOS' -only-testing:ai智剪Tests/SidebarVisibilityStoreTests 2>&1 | tail -30`
Expected: PASS

确保所有现有测试仍通过：
Run: `xcodebuild test -scheme ai智剪 -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests passed

- [ ] **Step 5: Commit Task 2**

```bash
git add ai智剪/Views/MainView.swift ai智剪Tests/SidebarVisibilityStoreTests.swift
git commit -m "feat: filter sidebar sections by SidebarVisibilityStore"
```

---

### Task 3: SettingsView 侧边栏管理 UI

**Files:**
- Modify: `ai智剪/Views/SettingsView.swift`
- Test: `ai智剪Tests/SidebarVisibilityStoreTests.swift`（追加 SettingsView 相关测试）

**设计分析:**
- 在 SettingsView 新增 Section("侧边栏管理")，位置在「通知」之后、「数据管理」之前
- 按 MainView 现有分组排列 Switch 列表，使用 Group 区分各分类
- 提供「恢复默认」按钮
- Toggle 标签使用 SidebarTab.rawValue + icon（Label）
- 每行用 `Label(tab.rawValue, systemImage: tab.icon)` + `Spacer()` + Toggle
- 管理页/首页不可隐藏（dashboard, adminXXX）— toggle 不显示或禁用

- [ ] **Step 1: 验证 SettingsView 可正常注入 Store**

```swift
// 追加到 SidebarVisibilityStoreTests
func testSettingsViewCanUseStore() {
    let store = SidebarVisibilityStore()
    store.setHidden(.seedance, true)
    store.setHidden(.voiceGen, true)
    // 验证 store 状态（SettingsView 将基于此渲染）
    XCTAssertFalse(store.isVisible(.seedance))
    XCTAssertFalse(store.isVisible(.voiceGen))
    XCTAssertTrue(store.isVisible(.dashboard))
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implementation — SettingsView.swift**

在 `SettingsView` struct 中增加：
```swift
@EnvironmentObject var sidebarVisibility: SidebarVisibilityStore
```

在 Form 中添加新的 Section，在「通知」和「数据管理」之间：

```swift
Section("侧边栏管理") {
    Text("选择在侧边栏中显示的功能，取消勾选后该功能将从侧边栏隐藏。")
        .font(.caption)
        .foregroundStyle(.secondary)
    
    // 首页（固定不可隐藏 — 不显示 toggle）
    if sidebarVisibility.isVisible(.dashboard) {
        // 只显示标签，不可操作
    }
    
    // 图片
    if sidebarVisibility.isVisible(.imageGen) || sidebarVisibility.isVisible(.banana) {
        Group {
            if sidebarVisibility.isVisible(.imageGen) {
                sidebarToggle(.imageGen)
            }
            if sidebarVisibility.isVisible(.banana) {
                sidebarToggle(.banana)
            }
        }
    }
    // ... 每个分类类似
}
```

**简化方案** — 直接显示所有 tab 的 toggle（除了首页和管理页不可隐藏的），这样更直观：

```swift
Section("侧边栏管理") {
    Text("选择在侧边栏中显示的功能，取消勾选后该功能将从侧边栏隐藏。")
        .font(.caption)
        .foregroundStyle(.secondary)
    
    // 首页 — 只读提示
    HStack {
        Label("首页", systemImage: "house")
        Spacer()
        Text("固定显示").foregroundStyle(.secondary).font(.caption)
    }
    
    // 分类展示
    Group {  // 图片
        Text("图片").font(.caption).foregroundStyle(.secondary)
        sidebarToggle(.imageGen)
        sidebarToggle(.banana)
    }
    Group {  // 视频生成
        Text("视频生成").font(.caption).foregroundStyle(.secondary)
        sidebarToggle(.seedance)
        sidebarToggle(.wan)
        sidebarToggle(.veo)
        sidebarToggle(.grok)
    }
    // ... 其他分类
    
    Divider()
    Button("恢复默认", role: .destructive) {
        sidebarVisibility.resetAll()
    }
}
```

辅助方法：
```swift
@ViewBuilder
private func sidebarToggle(_ tab: SidebarTab) -> some View {
    Toggle(isOn: Binding(
        get: { sidebarVisibility.isVisible(tab) },
        set: { sidebarVisibility.setHidden(tab, !$0) }
    )) {
        Label(tab.rawValue, systemImage: tab.icon)
    }
}
```

不可隐藏项：
```swift
// dashboard, settings, 所有 adminXX — 不显示 toggle 或显示为禁用态
// 使用 tab.isPinnable 来判断是否可隐藏（可置顶 = 可隐藏）
```

在 onAppear 中无需额外加载（EnvironmentObject 自动注入）。

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit Task 3**

```bash
git add ai智剪/Views/SettingsView.swift ai智剪Tests/SidebarVisibilityStoreTests.swift
git commit -m "feat: add sidebar visibility management section in SettingsView"
```

---

### Task 4: ai智剪App.swift 注入 SidebarVisibilityStore

**Files:**
- Modify: `ai智剪/ai智剪App.swift`

- [ ] **Step 1: Write verification test** — 验证 App 入口能正常创建 Store

追加到 SidebarVisibilityStoreTests：
```swift
func testAppCanCreateStore() {
    let store = SidebarVisibilityStore()
    XCTAssertNotNil(store)
    // 验证被 main App 正常初始化
    XCTAssertNoThrow(store.isVisible(.dashboard))
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implementation**

```swift
@main
struct AI____App: App {
    @StateObject private var api = APIService.shared
    @StateObject private var worksStore = WorksStore()
    @StateObject private var queueStore = GenerationQueueStore(api: APIService.shared)
    @StateObject private var editCoordinator = EditTaskCoordinator()
    @StateObject private var workflowStore = WorkflowStore(api: APIService.shared)
    @StateObject private var presetStore = PresetStore()
    @StateObject private var scriptStore = ScriptStore()
    @StateObject private var sidebarVisibility = SidebarVisibilityStore()  // ← 新增

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(worksStore)
                .environmentObject(queueStore)
                .environmentObject(editCoordinator)
                .environmentObject(workflowStore)
                .environmentObject(presetStore)
                .environmentObject(scriptStore)
                .environmentObject(sidebarVisibility)  // ← 新增
                .frame(minWidth: 960, minHeight: 680)
                .onAppear {
                    queueStore.attachWorksStore(worksStore)
                    workflowStore.attachWorksStore(worksStore)
                }
        }
        .windowStyle(.titleBar)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme ai智剪 -destination 'platform=macOS' 2>&1 | tail -20
```
Expected: All tests passed

- [ ] **Step 5: Commit Task 4**

```bash
git add ai智剪/ai智剪App.swift
git commit -m "feat: inject SidebarVisibilityStore as environment object"
```

---

### Task 5: Final Review + Build Validation

- [ ] **Step 1: Build the project to ensure no compilation errors**

```bash
xcodebuild build -scheme ai智剪 -destination 'platform=macOS' 2>&1 | tail -30
```

- [ ] **Step 2: Run all tests**

```bash
xcodebuild test -scheme ai智剪 -destination 'platform=macOS' 2>&1 | tail -30
```

- [ ] **Step 3: Verify all 4 files changed include the expected modifications**

```bash
git diff --stat
```

Expected: 
- ai智剪/Services/SidebarVisibilityStore.swift (new)
- ai智剪Tests/SidebarVisibilityStoreTests.swift (new)
- ai智剪/Views/MainView.swift (modified)
- ai智剪/Views/SettingsView.swift (modified)
- ai智剪/ai智剪App.swift (modified)
