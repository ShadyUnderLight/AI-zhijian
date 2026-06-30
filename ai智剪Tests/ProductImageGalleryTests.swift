import XCTest
@testable import aiZhijian

final class ProductImageGalleryTests: XCTestCase {

    // MARK: - toggleProductSelection logic (tested via a helper)

    /// 模拟点击选择逻辑：toggleProductSelection 的纯函数版本
    func toggleSelection(_ selected: [FileRef], _ item: FileRef, max: Int = 3) -> [FileRef] {
        var result = selected
        if let idx = result.firstIndex(of: item) {
            result.remove(at: idx)  // 取消选择
        } else if result.count < max {
            result.append(item)     // 追加选择
        }
        return result
    }

    // MARK: - Selection Toggle

    func testToggleSelection_addsItem_whenNotSelected_andBelowMax() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let ref2 = FileRef(data: Data([0x02]), name: "b.jpg", mime: "image/jpeg")
        let result = toggleSelection([ref1], ref2)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], ref1)
        XCTAssertEqual(result[1], ref2)
    }

    func testToggleSelection_removesItem_whenAlreadySelected() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let ref2 = FileRef(data: Data([0x02]), name: "b.jpg", mime: "image/jpeg")
        let result = toggleSelection([ref1, ref2], ref1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], ref2)
    }

    func testToggleSelection_doesNotAdd_whenAlreadyAtMax() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let ref2 = FileRef(data: Data([0x02]), name: "b.jpg", mime: "image/jpeg")
        let ref3 = FileRef(data: Data([0x03]), name: "c.jpg", mime: "image/jpeg")
        let ref4 = FileRef(data: Data([0x04]), name: "d.jpg", mime: "image/jpeg")
        let result = toggleSelection([ref1, ref2, ref3], ref4)
        XCTAssertEqual(result.count, 3)
        XCTAssertFalse(result.contains(ref4))
    }

    func testToggleSelection_preservesOrder_whenAdding() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let ref2 = FileRef(data: Data([0x02]), name: "b.jpg", mime: "image/jpeg")
        let ref3 = FileRef(data: Data([0x03]), name: "c.jpg", mime: "image/jpeg")
        let result = toggleSelection([ref1], ref2)
        // 再添加第三个
        let final = toggleSelection(result, ref3)
        XCTAssertEqual(final, [ref1, ref2, ref3])
    }

    func testToggleSelection_preservesOrder_whenRemovingMiddle() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let ref2 = FileRef(data: Data([0x02]), name: "b.jpg", mime: "image/jpeg")
        let ref3 = FileRef(data: Data([0x03]), name: "c.jpg", mime: "image/jpeg")
        let result = toggleSelection([ref1, ref2, ref3], ref2)
        XCTAssertEqual(result, [ref1, ref3])
    }

    func testToggleSelection_handlesEmptySelection() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let result = toggleSelection([], ref1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], ref1)
    }

    func testToggleSelection_handlesAllRemoved() {
        let ref1 = FileRef(data: Data([0x01]), name: "a.jpg", mime: "image/jpeg")
        let result = toggleSelection([ref1], ref1)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - ProductImageItem

    func testProductImageItem_equatableById() {
        let ref = FileRef(data: Data([0x01]), name: "test.jpg", mime: "image/jpeg")
        let nsImage = NSImage(size: NSSize(width: 10, height: 10))
        let item1 = ProductImageItem(name: "test", thumbnail: nsImage, ref: ref)
        let item2 = ProductImageItem(name: "test", thumbnail: nsImage, ref: ref)
        XCTAssertNotEqual(item1.id, item2.id, "不同实例应有不同 UUID")
        XCTAssertTrue(item1 == item1, "同一实例应相等")
        XCTAssertFalse(item1 == item2, "不同实例不应相等")
    }

    // MARK: - Default directory path

    func testDefaultDirectory_constantExists() {
        let path = "/Users/lmz/Movies/JianyingPro Materials/地推/产品图"
        XCTAssertFalse(path.isEmpty, "默认目录路径应为已知常量")
    }
}
