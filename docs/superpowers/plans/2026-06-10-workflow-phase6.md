# 第六阶段：工作流补齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Implement 4 workflow UIs in the macOS client: 文→图→视频 (template), Grok-Veo (template), 健康科普 (page), 软广 (page)

**Architecture:** Follow existing patterns: templates in `WorkflowModels.swift`, dedicated pages as new files in `Views/`, API extensions in new `APIService+*.swift` files

**Tech Stack:** SwiftUI, APIService, WorkflowStore, GenerationQueueStore

---

### Task 1: Add 文→图→视频 DAG Template

**Files:**
- Modify: `ai智剪/Services/WorkflowModels.swift` (~100 lines)
- Test: `ai智剪Tests/WorkflowCanvasTests.swift` (+5 lines)

- [ ] **Step 1: Add the text-to-image-to-video-lite template**

Add a new template `textToImageToVideoLite` in `WorkflowModels.swift` after the existing templates. This is a 3-node DAG:
- Input node (text)
- Image gen node (takes text → generates image)
- Video gen node (takes image → generates video)

- [ ] **Step 2: Register in templates array**

Add `textToImageToVideoLite` to `WorkflowDefinition.templates`.

- [ ] **Step 3: Commit**

### Task 2: Add Grok-Veo 联合 DAG Template

**Files:**
- Modify: `ai智剪/Services/WorkflowModels.swift` (~50 lines)

- [ ] **Step 1: Add the grok-veo-combined template**

A DAG template with 3 text input nodes (shot descriptions) → 2 video gen nodes (Grok + Veo) → result output.

- [ ] **Step 2: Register in templates array**

- [ ] **Step 3: Commit**

### Task 3: Implement DAG batch execution (batchImageGen/batchVideoGen/videoConcat)

**Files:**
- Modify: `ai智剪/Services/WorkflowStore.swift` (~100 lines)
- Test: `ai智剪Tests/WorkflowCanvasTests.swift` (~50 lines)

- [ ] **Step 1: Implement batchImageGen execution**
- [ ] **Step 2: Implement batchVideoGen execution**
- [ ] **Step 3: Implement videoConcat execution**
- [ ] **Step 4: Write tests and verify**
- [ ] **Step 5: Commit**

### Task 4: Health科普 workflow — API + View + Sidebar

**Files:**
- Create: `ai智剪/Services/APIService+Health.swift`
- Create: `ai智剪/Views/HealthActionWorkflowView.swift`
- Modify: `ai智剪/Views/MainView.swift`

- [ ] **Step 1: Write APIService+Health.swift**
- [ ] **Step 2: Write HealthActionWorkflowView.swift**
- [ ] **Step 3: Register in MainView.swift (SidebarTab + detailView)**
- [ ] **Step 4: Commit**

### Task 5: 软广 workflow — API + View + Sidebar

**Files:**
- Create: `ai智剪/Services/APIService+SoftAd.swift`
- Create: `ai智剪/Views/SoftAdWorkflowView.swift`
- Modify: `ai智剪/Views/MainView.swift`

- [ ] **Step 1: Write APIService+SoftAd.swift**
- [ ] **Step 2: Write SoftAdWorkflowView.swift**
- [ ] **Step 3: Register in MainView.swift (SidebarTab + detailView)**
- [ ] **Step 4: Commit**

### Task 6: Run tests and verify

**Files:**
- Run: `ai智剪Tests/` all tests

- [ ] **Step 1: Build project**
- [ ] **Step 2: Run all tests**
- [ ] **Step 3: Fix any failures**
- [ ] **Step 4: Commit**

### Task 7: Open PR

- [ ] **Step 1: Push branch**
- [ ] **Step 2: Create PR**
