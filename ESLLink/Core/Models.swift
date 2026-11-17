import Foundation

struct Scenario {
    var id = "", key = "", name = ""
    var isItems: Bool {
        key.trimmed.lowercased() == "items" || name.trimmed.lowercased() == "items"
    }
    var title: String { name.isEmpty ? key : name }
}

struct Field {
    var column: String, label: String
}

struct Item {
    var id = "", code = "", name = "", tags = ""
    var bindState = 0
    var dyn: J = [:]

    static func from(_ o: J) -> Item {
        var it = Item()
        it.id = Json.s(o, "itemId")
        it.code = Json.s(o, "itemCode")
        it.name = Json.s(o, "itemName")
        it.tags = Json.s(o, "itemTags")
        it.bindState = Json.i(o, "bindState", 0)
        it.dyn = Json.obj(o, "dynamicFields") ?? [:]
        return it
    }

    func field(_ col: String) -> String { Json.s(dyn, col) }

    var bound: Bool { bindState == 1 || !tags.isEmpty }
}

struct TagBinding {
    var middleId = "", itemCode = "", itemName = "", layoutId = ""
    var itemTag = 0
    /// itemTag polja kako ga server vraca (npr. "1" ili naziv polja) – za poziciju u layoutu
    var itemTagStr = ""
}

struct Tag {
    var tagId = "", code = "", typeId = "", typeName = "", state = "", power = "", lqi = "",
        mac = "", time = "", ver = "", strategyIdOnTag = "", connectivity = "", storeName = ""
    var layoutId = "", layoutName = "", strategyId = "", strategyName = ""
    var maxBind = 0
    var bindings: [TagBinding] = []

    static func from(_ d: J) -> Tag {
        var t = Tag()
        t.tagId = Json.s(d, "tagId")
        t.code = Json.s(d, "tagIdentity")
        t.typeId = Json.s(d, "tagTypeId")
        t.typeName = Json.s(d, "tagTypeName")
        t.state = Json.s(d, "tagStateName")
        t.power = Json.s(d, "tagPower")
        t.lqi = Json.s(d, "lqi")
        t.mac = Json.s(d, "macAddress")
        t.time = Json.s(d, "tagTime")
        t.ver = Json.s(d, "ver")
        t.strategyIdOnTag = Json.s(d, "layoutId")
        t.connectivity = Json.s(d, "connectivityName")
        t.storeName = Json.s(d, "storeName")
        if let le = Json.obj(d, "layoutEntity") {
            t.layoutId = Json.s(le, "layoutId")
            t.layoutName = Json.s(le, "layoutName")
            t.strategyId = Json.s(le, "layoutStrategyId")
            t.strategyName = Json.s(le, "layoutStrategyName")
            t.maxBind = max(Json.i(le, "maxBind", 0), Json.i(le, "maxBindNumber", 0))
        }
        if let bl = Json.arr(d, "goodsTagMiddleEntityList") {
            for (k, x) in bl.enumerated() {
                guard let b = x as? J else { continue }
                var bd = TagBinding()
                bd.middleId = Json.s(b, "goodsTagMiddleId")
                bd.itemCode = Json.s(b, "itemCode")
                bd.itemName = Json.s(b, "itemName")
                bd.layoutId = Json.s(b, "layoutId")
                bd.itemTag = Json.i(b, "itemTag", k + 1)
                bd.itemTagStr = Json.s(b, "itemTag")
                if t.layoutId.isEmpty { t.layoutId = bd.layoutId }
                if t.layoutName.isEmpty { t.layoutName = Json.s(b, "layoutName") }
                t.bindings.append(bd)
            }
        }
        if t.bindings.isEmpty, let gc = Json.arr(d, "goodsCode") {
            let gn = Json.arr(d, "goodsName")
            for (k, c0) in gc.enumerated() {
                let c = Json.str(c0)
                if c.isEmpty { continue }
                var bd = TagBinding()
                bd.itemCode = c
                bd.itemName = gn != nil && k < gn!.count ? Json.str(gn![k]) : ""
                bd.itemTag = k + 1
                t.bindings.append(bd)
            }
        }
        t.bindings = t.bindings.enumerated().sorted {
            $0.element.itemTag != $1.element.itemTag ? $0.element.itemTag < $1.element.itemTag : $0.offset < $1.offset
        }.map { $0.element }
        return t
    }

    func goodsSummary() -> String {
        bindings.map { $0.itemCode + ($0.itemName.isEmpty ? "" : " " + $0.itemName) }.joined(separator: ", ")
    }
}

final class Layout {
    var id = "", name = "", strategyId = "", strategyName = ""
    var strategyType = 0, maxBind = 0, lumps = 0
    /// itemTag svakog polja (layout lump) po redosledu – koristi se pri linku ("itemTag:itemId").
    var lumpTags: [String] = []

    var title: String { name + (strategyName.isEmpty ? "" : "  [" + strategyName + "]") }

    func slots() -> Int {
        if maxBind > 1 { return maxBind }
        if lumps > 1 { return lumps }
        return strategyType == 0 ? 1 : 2
    }
}

final class Strategy {
    var id = "", name = "", scenarioId = ""
    var type = -1
    var layouts: [Layout] = []
}

final class LayoutGroup {
    var id = "", name = "", sizeName = ""
    var strategies: [Strategy] = []

    static func from(_ g: J) -> LayoutGroup {
        let lg = LayoutGroup()
        lg.id = Json.s(g, "layoutGroupId")
        lg.name = Json.s(g, "layoutGroupName")
        lg.sizeName = Json.s(g, "layoutGroupSizeName")
        for case let so as J in Json.arr(g, "children") ?? [] {
            let str = Strategy()
            str.id = Json.s(so, "layoutStrategyId")
            str.name = Json.s(so, "layoutStrategyName")
            str.scenarioId = Json.s(so, "scenarioId")
            str.type = Json.i(so, "layoutStrategyType", -1)
            var maxSeen = 0
            for case let lo as J in Json.arr(so, "children") ?? [] {
                if Json.i(lo, "isEffect", 0) == 1 { continue }
                let l = Layout()
                l.id = Json.s(lo, "layoutId")
                l.name = Json.s(lo, "layoutName")
                l.strategyId = str.id
                l.strategyName = str.name.isEmpty ? Json.s(lo, "layoutStrategyName") : str.name
                l.maxBind = max(Json.i(lo, "maxBind", 0), Json.i(lo, "maxBindNumber", 0))
                let lumps = Json.arr(lo, "children")
                l.lumps = lumps?.count ?? 0
                if let lumps = lumps {
                    let ll = lumps.compactMap { $0 as? J }.enumerated().sorted {
                        let a = Json.i($0.element, "sort", 0), b = Json.i($1.element, "sort", 0)
                        return a != b ? a < b : $0.offset < $1.offset
                    }.map { $0.element }
                    l.lumpTags = ll.map { Json.s($0, "itemTag") }
                }
                maxSeen = max(maxSeen, max(l.maxBind, l.lumps))
                str.layouts.append(l)
            }
            if str.type < 0 {
                let n = str.name.lowercased()
                if n.contains("adapt") { str.type = 2 }
                else if n.contains("split") { str.type = 1 }
                else if n.contains("normal") { str.type = 0 }
                else { str.type = maxSeen > 1 ? 1 : 0 }
            }
            for l in str.layouts { l.strategyType = str.type }
            lg.strategies.append(str)
        }
        return lg
    }
}
