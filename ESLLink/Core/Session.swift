import Foundation

/// Prijavljena sesija: korisnik, prodavnica, scenario i poslovna logika.
final class Session {
    let api: Api
    let server: Server
    var userId, storeId, merchantId, agentId, loginId, userName, storeName, defaultScenarioId: String
    var scenarioId = "", scenarioName = ""
    var warning = ""
    var scenarios: [Scenario] = []
    var fields: [Field] = []
    /// Prodavnice naloga (prijavljena + podprodavnice): id, naziv, dubina u stablu.
    var stores: [(id: String, name: String, depth: Int)] = []

    private var layoutGroups: [LayoutGroup]?
    private var allItemsCache: [Item]?
    private let lock = NSRecursiveLock()

    init(_ api: Api, _ server: Server, _ d: J) {
        self.api = api
        self.server = server
        userId = Json.s(d, "userId")
        storeId = Json.s(d, "storeId")
        merchantId = Json.s(d, "merchantId")
        agentId = Json.s(d, "agentId")
        let lid = Json.s(d, "loginId")
        loginId = lid.isEmpty ? api.account : lid
        userName = Json.s(d, "userName")
        storeName = Json.s(d, "storeName")
        defaultScenarioId = Json.s(d, "defaultScenarioId")
    }

    private func body() -> J { ["storeId": storeId] }

    // ------------------------------------------------------------ scenario

    /// Sifre prodavnice za link servis (third API je vezan za prodavnicu).
    func loadStore() {
        var b = body()
        if !storeName.isEmpty { b["storeName"] = storeName }
        guard let d = Json.obj(try? api.app("app/store/v1/switchPage", b), "data") else { return }
        if stores.isEmpty { collectStores(d, 0) }
        for k in ["customerStoreCode", "storeCode"] {
            let v = Json.s(d, k)
            if !v.isEmpty && !api.storeCodes.contains(v) { api.storeCodes.append(v) }
        }
    }

    private func collectStores(_ o: J?, _ depth: Int) {
        guard let o = o, depth <= 8 else { return }
        let id = Json.s(o, "storeId")
        if !id.isEmpty && !stores.contains(where: { $0.id == id }) {
            stores.append((id: id, name: Json.s(o, "storeName"), depth: depth))
        }
        for key in ["nextStoreList", "child", "children"] {
            for case let c as J in Json.arr(o, key) ?? [] {
                if let si = Json.obj(c, "storeInfo"), Json.s(c, "storeName").isEmpty {
                    collectStores(si, depth + 1)
                } else {
                    collectStores(c, depth + 1)
                }
            }
        }
    }

    /// Prelazak na drugu prodavnicu (podprodavnicu) – kao "Switch Store" u Price Touch aplikaciji.
    func switchStore(_ id: String, _ name: String) throws {
        let oldId = storeId, oldName = storeName
        storeId = id
        storeName = name
        let d: J?
        do {
            var b = body()
            if !storeName.isEmpty { b["storeName"] = storeName }
            d = Json.obj(try api.app("app/store/v1/switchPage", b), "data")
        } catch {
            storeId = oldId
            storeName = oldName
            throw error
        }
        lock.lock()
        allItemsCache = nil
        layoutGroups = nil
        lock.unlock()
        layoutTagCache.removeAll()
        api.storeCodes.removeAll()
        if let d = d {
            if !Json.s(d, "storeName").isEmpty { storeName = Json.s(d, "storeName") }
            for k in ["customerStoreCode", "storeCode"] {
                let v = Json.s(d, k)
                if !v.isEmpty && !api.storeCodes.contains(v) { api.storeCodes.append(v) }
            }
        }
    }

    func loadScenarios() throws {
        loadStore()
        let b: J = ["merchantId": merchantId, "agentId": agentId, "isEffect": "0"]
        let a = Json.records(try api.app("app/item/v1/getScenarioList", b)["data"])
        scenarios.removeAll()
        var items: [Scenario] = []
        for o in a {
            var sc = Scenario()
            sc.id = Json.s(o, "scenarioId")
            sc.key = Json.s(o, "scenarioKey")
            sc.name = Json.s(o, "translateTextName")
            if sc.name.isEmpty { sc.name = Json.s(o, "defaultTextName") }
            if sc.isItems { items.append(sc) } else { scenarios.append(sc) }
        }
        var chosen = scenarios.last { $0.id == server.scenarioId }
        if chosen == nil && !scenarios.isEmpty { chosen = scenarios[0] }
        if chosen == nil && !items.isEmpty {
            chosen = items[0]
            warning = "Ne postoji scenario osim Items — koristi se Items."
            scenarios.append(contentsOf: items)
        }
        guard let c = chosen else { throw AppError.api("Na serveru nije pronađen nijedan scenario") }
        selectScenario(c)
    }

    func selectScenario(_ sc: Scenario) {
        scenarioId = sc.id
        scenarioName = sc.title
        api.scenarioId = sc.id
        api.scenarioKey = sc.key
        lock.lock(); allItemsCache = nil; lock.unlock()
        fields.removeAll()
        // polja su samo za prikaz / dodatnu pretragu
        guard let d = Json.obj(try? api.app("app/item/v1/getScenario", ["scenarioId": scenarioId]), "data") else { return }
        for case let g as J in Json.arr(d, "groupList") ?? [] {
            for case let fo as J in Json.arr(g, "fieldList") ?? [] {
                let col = Json.s(fo, "columnName")
                if col.isEmpty { continue }
                var lbl = Json.s(fo, "translateTextName")
                if lbl.isEmpty { lbl = Json.s(fo, "defaultTextName") }
                if lbl.isEmpty { lbl = col }
                fields.append(Field(column: col, label: lbl))
            }
        }
    }

    func fieldLabel(_ col: String) -> String { fields.first { $0.column == col }?.label ?? col }

    // ------------------------------------------------------------ layouts

    func layouts(_ refresh: Bool) throws -> [LayoutGroup] {
        lock.lock(); defer { lock.unlock() }
        if let l = layoutGroups, !refresh { return l }
        var l: [LayoutGroup] = []
        let size = 100
        for page in 1...20 {
            var b = body()
            b["storeQueryType"] = "2"
            b["current"] = String(page)
            b["size"] = String(size)
            let a = Json.records(try api.app("app/layout/v1/getList", b)["data"])
            l.append(contentsOf: a.map(LayoutGroup.from))
            if a.count < size { break }
        }
        layoutGroups = l
        return l
    }

    func groupFor(_ t: Tag) throws -> LayoutGroup? {
        let tn = t.typeName.lowercased().trimmed
        var best: LayoutGroup?
        for g in try layouts(false) {
            let sn = g.sizeName.lowercased().trimmed
            if sn.isEmpty { continue }
            if tn.hasPrefix(sn) && (best == nil || sn.count > best!.sizeName.count) { best = g }
        }
        return best
    }

    /// Layout-i za tip etikete i trenutni scenario. multi=false -> Normal, multi=true -> split/self adapt.
    func layoutsFor(_ t: Tag, _ multi: Bool) throws -> [Layout] {
        guard let g = try groupFor(t) else { return [] }
        var res: [Layout] = []
        for st in g.strategies {
            if !st.scenarioId.isEmpty && st.scenarioId != scenarioId { continue }
            let split = st.type == 1 || st.type == 2
            if split != multi { continue }
            res.append(contentsOf: st.layouts)
        }
        return res
    }

    /// -1 nepoznato, 0 normal, 1 split screen, 2 self adapt
    func strategyType(_ t: Tag) -> Int {
        let sid = !t.strategyId.isEmpty ? t.strategyId : t.strategyIdOnTag
        if let groups = try? layouts(false) {
            for g in groups {
                for st in g.strategies {
                    if !sid.isEmpty && st.id == sid { return st.type }
                    for l in st.layouts where !t.layoutId.isEmpty && l.id == t.layoutId { return st.type }
                }
            }
        }
        let n = t.strategyName.lowercased()
        if n.contains("adapt") { return 2 }
        if n.contains("split") { return 1 }
        if n.contains("normal") { return 0 }
        if t.maxBind > 1 || t.bindings.count > 1 { return 1 }
        return t.maxBind == 1 ? 0 : -1
    }

    // ------------------------------------------------------------ tags

    /// Vraca etiketu ili nil ako ne postoji.
    func getTag(_ code: String) throws -> Tag? {
        var b = body()
        b["tagIdentity"] = code
        let d: J?
        do {
            d = Json.obj(try api.app("app/tag/v1/getByEslCode", b), "data")
        } catch AppError.api(_) {
            return nil
        }
        guard let dd = d, !(Json.s(dd, "tagIdentity").isEmpty && Json.s(dd, "tagId").isEmpty) else { return nil }
        var t = Tag.from(dd)
        if t.code.isEmpty { t.code = code }
        if t.typeName.isEmpty, let a = try? tagList(code, 0, 1, 10) {
            for o in a where code.lowercased() == Json.s(o, "tagIdentity").lowercased() {
                t.typeName = Json.s(o, "tagTypeName")
                if t.bindings.isEmpty { t.bindings = Tag.from(o).bindings }
            }
        }
        return t
    }

    /// bind: 0 sve, 1 linkovane, 2 nelinkovane
    func tagList(_ param: String?, _ bind: Int, _ page: Int, _ size: Int) throws -> [J] {
        Json.records(try tagListRaw(param, bind, page, size)["data"])
    }

    func tagListRaw(_ param: String?, _ bind: Int, _ page: Int, _ size: Int) throws -> J {
        var b = body()
        b["storeQueryType"] = "2"
        b["isEffect"] = "0"
        if let p = param, !p.isEmpty {
            b["param"] = p
            b["tagIdentity"] = p // Price Touch trazi etiketu po tagIdentity
        }
        b["bind"] = String(bind)
        b["current"] = String(page)
        b["size"] = String(size)
        return try api.app("app/tag/v1/getList", b)
    }

    /// ESL kodovi etiketa na kojima su artikli koji odgovaraju pretrazi (kod / naziv).
    func eslCodesForItemSearch(_ q: String) throws -> [String] {
        var b = body()
        b["scenarioId"] = scenarioId
        b["fuzzySearch"] = "true"
        b["param"] = q
        b["current"] = "1"
        b["size"] = "50"
        var out: [String] = []
        for o in Json.records(try api.app("app/tag/v1/getTagBindList", b)["data"]) {
            let c = Json.s(o, "tagIdentity")
            if !c.isEmpty && !out.contains(c) { out.append(c) }
        }
        return out
    }

    /// Lista problematicnih etiketa: lowpower, offline, weak
    func problemList(_ type: String, _ page: Int, _ size: Int) throws -> J {
        let path = type == "offline" ? "app/tag/v1/getNotActiveTagList"
            : type == "weak" ? "app/tag/v1/getLowLpiTagList" : "app/tag/v1/getLowPowerTagList"
        var b = body()
        b["merchantId"] = merchantId
        b["agentId"] = agentId
        b["current"] = String(page)
        b["size"] = String(size)
        return try api.app(path, b)
    }

    /// Etikete na kojima je artikal linkovan.
    func eslsForItem(_ itemCode: String) throws -> [String] {
        var b = body()
        b["scenarioId"] = scenarioId
        b["fuzzySearch"] = "false"
        b["param"] = itemCode
        b["current"] = "1"
        b["size"] = "200"
        var res: [String] = []
        for o in Json.records(try api.app("app/tag/v1/getTagBindList", b)["data"]) {
            let esl = Json.s(o, "tagIdentity")
            if esl.isEmpty { continue }
            if itemCode.lowercased() != Json.s(o, "itemCode").lowercased() { continue }
            if !res.contains(esl) { res.append(esl) }
        }
        return res
    }

    func otherEslsForItem(_ itemCode: String, _ exceptEsl: String) throws -> [String] {
        try eslsForItem(itemCode).filter { $0.lowercased() != exceptEsl.lowercased() }
    }

    /// goodsTagMiddleId za sve veze etikete.
    func middleIds(_ t: Tag) throws -> [String] {
        var ids = t.bindings.map { $0.middleId }.filter { !$0.isEmpty }
        if ids.isEmpty {
            var b = body()
            b["scenarioId"] = scenarioId
            b["fuzzySearch"] = "false"
            b["param"] = t.code
            b["current"] = "1"
            b["size"] = "50"
            for o in Json.records(try api.app("app/tag/v1/getTagBindList", b)["data"])
            where t.code.lowercased() == Json.s(o, "tagIdentity").lowercased() && !Json.s(o, "goodsTagMiddleId").isEmpty {
                ids.append(Json.s(o, "goodsTagMiddleId"))
            }
        }
        return ids
    }

    /// Unlink po ID-jevima veza (kao Price Touch aplikacija).
    func unlinkMiddle(_ ids: [String]) throws {
        if ids.isEmpty { return }
        if ids.count == 1 {
            try api.app("app/bind/v1/unBind", ["goodsTagMiddleId": Json.num(ids[0])])
        } else {
            try api.app("app/bind/v1/batchUnBind", ["goodsTagMiddleIdList": ids.map(Json.num)])
        }
    }

    /// Odvezuje sve artikle sa etikete.
    func unlinkAll(_ t: Tag) throws {
        let ids = try middleIds(t)
        if ids.isEmpty {
            if t.bindings.isEmpty { return }
            try api.unbind(t.code) // rezerva: third API
            return
        }
        try unlinkMiddle(ids)
    }

    /// Skida jedan artikal sa etikete, ostali ostaju.
    func removeItemFromEsl(_ esl: String, _ itemCode: String) throws {
        guard let t = try getTag(esl) else { return }
        let ids = t.bindings.filter { $0.itemCode.lowercased() == itemCode.lowercased() && !$0.middleId.isEmpty }.map { $0.middleId }
        try unlinkMiddle(ids)
    }

    func removeBinding(_ t: Tag, _ bd: TagBinding) throws {
        if !bd.middleId.isEmpty { try unlinkMiddle([bd.middleId]) }
        else { try removeItemFromEsl(t.code, bd.itemCode) }
    }

    private var layoutTagCache: [String: [String]] = [:]

    /// itemTag polja layouta, kao u Price Touch aplikaciji (app/layout/v1/get, children sa itemTag).
    func layoutItemTags(_ l: Layout) throws -> [String] {
        if let c = layoutTagCache[l.id] { return c }
        var out: [String] = []
        do {
            let d = Json.obj(try api.app("app/layout/v1/get", ["layoutId": Json.num(l.id)]), "data")
            for case let ch as J in Json.arr(d, "children") ?? [] {
                let tg = Json.s(ch, "itemTag")
                if !tg.isEmpty { out.append(tg) }
            }
        } catch AppError.api(_) {
            // ignorisi, koristi podatke iz liste layouta
        }
        if out.isEmpty { out = l.lumpTags.filter { !$0.isEmpty } }
        layoutTagCache[l.id] = out
        return out
    }

    /// Link kao u Price Touch aplikaciji: app/bind/v1/bind sa itemId = "itemTag:itemCode".
    func link(_ t: Tag, _ l: Layout, _ items: [Item], _ slots: [Int]?) throws {
        let tagsOfLayout = try layoutItemTags(l)
        var ids: [String] = []
        for (k, it) in items.enumerated() {
            let slot = slots != nil && k < slots!.count ? slots![k] : k
            let tg: String? = tagsOfLayout.isEmpty ? "1" : (slot < tagsOfLayout.count ? tagsOfLayout[slot] : nil)
            guard let tag = tg else { throw AppError.msg("Layout \(l.name) nema polje \(slot + 1)") }
            ids.append(tag + ":" + it.code)
        }
        let b: J = [
            "itemId": ids,
            "layoutId": Json.num(l.id),
            "scenarioId": Json.num(scenarioId),
            "storeId": Json.num(storeId),
            "tagId": Json.num(t.tagId),
        ]
        do {
            try api.app("app/bind/v1/bind", b)
        } catch AppError.http(let code, let m) {
            if code != 404 { throw AppError.http(code, m) }
            // stariji server bez app/bind – rezerva preko third API
            var tags: [Int] = []
            for k in 0..<items.count { tags.append((slots != nil && k < slots!.count ? slots![k] : k) + 1) }
            try bindItems(t.code, items, tags, l.id)
        }
    }

    // ------------------------------------------------------------ link

    private static func itemMissing(_ m: String?) -> Bool {
        let l = (m ?? "").lowercased()
        return (l.contains("item") || l.contains("goods") || l.contains("sku")) && (l.contains("not exist") || l.contains("not found"))
            || l.contains("不存在") || l.contains("kod 1000")
    }

    /// Moguce sifre artikla za link servis: Item code, pa polja tipa barkod/EAN/SKU/PLU.
    func skuCandidates(_ it: Item) -> [String] {
        var l = [it.code]
        if let re = try? NSRegularExpression(pattern: "^\\s*\\((\\w+)\\)"),
           let m = re.firstMatch(in: it.name, range: NSRange(it.name.startIndex..., in: it.name)),
           let r = Range(m.range(at: 1), in: it.name) {
            let g = String(it.name[r])
            if !l.contains(g) { l.append(g) }
        }
        for f in fields {
            let n = (f.label + " " + f.column).lowercased()
            if !(n.contains("barcode") || n.contains("bar code") || n.contains("barkod") || n.contains("ean")
                 || n.contains("gtin") || n.contains("upc") || n.contains("sku") || n.contains("plu")) { continue }
            let v = it.field(f.column).trimmed
            if !v.isEmpty && !l.contains(v) { l.append(v) }
        }
        return l
    }

    /// Link artikala na etiketu; ako server javi da artikal ne postoji, pokusava sa barkod poljima.
    func bindItems(_ esl: String, _ items: [Item], _ tags: [Int], _ layoutId: String) throws {
        let cand = items.map(skuCandidates)
        var rounds = 1
        for c in cand { rounds = max(rounds, min(c.count, 4)) }
        var first: String?
        for r in 0..<rounds {
            let codes = cand.map { $0[min(r, $0.count - 1)] }
            do {
                try api.bind(esl, codes, tags, layoutId)
                return
            } catch AppError.api(let m) {
                if first == nil { first = m }
                if !Session.itemMissing(m) { throw AppError.api(m) }
            }
        }
        throw AppError.api((first ?? "") + "\n\nLink servis ne pronalazi artikal. Proveri da li artikal postoji i u scenariju koji link servis koristi (npr. Items) ili da li link servis očekuje barkod umesto Item code-a.")
    }

    // ------------------------------------------------------------ items

    struct Page {
        var items: [Item] = []
        var total = 0
    }

    func itemsPage(_ itemInfo: String?, _ findBy: Int, _ page: Int, _ size: Int) throws -> Page {
        var b = body()
        b["scenarioId"] = scenarioId
        b["storeType"] = 2 // samo artikli ove prodavnice (kao u Price Touch aplikaciji)
        if let q = itemInfo, !q.isEmpty {
            b["itemInfo"] = q
            b["findBy"] = String(findBy)
        }
        b["current"] = String(page)
        b["size"] = String(size)
        let data = try api.app("app/item/v1/getItemList", b)["data"]
        var p = Page()
        p.items = Json.records(data).map(Item.from)
        p.total = (data as? J).map { Json.i($0, "total", p.items.count) } ?? p.items.count
        return p
    }

    func allItems() throws -> [Item] {
        lock.lock(); defer { lock.unlock() }
        if let l = allItemsCache { return l }
        var l: [Item] = []
        let size = 200
        for page in 1...250 {
            let p = try itemsPage(nil, 0, page, size)
            l.append(contentsOf: p.items)
            if p.items.count < size || l.count >= p.total { break }
        }
        allItemsCache = l
        return l
    }

    func clearItemCache() { lock.lock(); allItemsCache = nil; lock.unlock() }

    private static func has(_ v: String, _ q: String) -> Bool { v.lowercased().contains(q) }

    private func matches(_ it: Item, _ q: String) -> Bool {
        var code = server.searchCode, name = server.searchName
        let extra = !server.extraField.isEmpty
        if !code && !name && !extra { code = true; name = true }
        return (code && Session.has(it.code, q)) || (name && Session.has(it.name, q)) || (extra && Session.has(it.field(server.extraField), q))
    }

    private func rank(_ it: Item, _ q: String) -> Int {
        if it.code.lowercased() == q { return 0 }
        if !server.extraField.isEmpty && it.field(server.extraField).lowercased() == q { return 0 }
        if it.name.lowercased() == q { return 1 }
        if it.code.lowercased().hasPrefix(q) { return 2 }
        return 3
    }

    func isExact(_ it: Item, _ q: String) -> Bool { rank(it, q.trimmed.lowercased()) == 0 }

    /// Case-insensitive pretraga po ItemCode, ItemName i izabranom dodatnom polju.
    func searchItems(_ query: String) throws -> [Item] {
        let q = query.trimmed.lowercased()
        var res: [Item] = []
        var seen = Set<String>()
        if q.isEmpty { return res }
        func addAll(_ items: [Item]) {
            for it in items where matches(it, q) && seen.insert(it.id + "|" + it.code).inserted { res.append(it) }
        }
        if server.searchCode || server.searchName {
            if let p = try? itemsPage(query.trimmed, 0, 1, 100) { addAll(p.items) }
        }
        // ako server nista ne vrati, probaj i varijante velikih/malih slova (brzo, bez ucitavanja svih artikala)
        if res.isEmpty && (server.searchCode || server.searchName) {
            let t = query.trimmed
            for v in [t.uppercased(), t.lowercased()] where v != t {
                if let p = try? itemsPage(v, 0, 1, 100) { addAll(p.items) }
                if !res.isEmpty { break }
            }
        }
        // svi artikli lokalno samo za dodatno polje (ili ako su vec ucitani)
        lock.lock(); let cached = allItemsCache != nil; lock.unlock()
        if !server.extraField.isEmpty || (res.isEmpty && cached) {
            addAll(try allItems())
        }
        var sorted = res.enumerated().sorted {
            let a = rank($0.element, q), b = rank($1.element, q)
            return a != b ? a < b : $0.offset < $1.offset
        }.map { $0.element }
        // barkod sa vodecim nulama: prodavnica ga nekad zaduzi sa 0, nekad sa 00, nekad bez nule.
        // Ako nema tacnog pogotka, probaj isti broj sa 0, 1 i 2 vodece nule.
        if !sorted.contains(where: { rank($0, q) == 0 }) && (server.searchCode || server.searchName) {
            var hits: [Item] = []
            for v in Session.zeroVariants(query.trimmed) {
                if let p = try? itemsPage(v, 0, 1, 100) {
                    for it in p.items where it.code.lowercased() == v.lowercased() && seen.insert(it.id + "|" + it.code).inserted { hits.append(it) }
                }
                if !hits.isEmpty { break }
            }
            sorted.insert(contentsOf: hits, at: 0)
        }
        return sorted
    }

    /// Varijante barkoda sa 0, 1 i 2 vodece nule (samo cifre, najmanje 6).
    static func zeroVariants(_ q: String) -> [String] {
        guard q.count >= 6, q.allSatisfy({ $0.isASCII && $0.isNumber }) else { return [] }
        let n = q.prefix(while: { $0 == "0" }).count
        if n > 2 { return [] }
        let core = String(q.dropFirst(n))
        var out: [String] = []
        // prvo manje nula (najcesci slucaj: skener procita 00, a artikal je zaduzen sa 0)
        for k in [n - 1, n - 2, n + 1, n + 2] where k >= 0 && k <= 2 && k != n {
            let v = String(repeating: "0", count: k) + core
            if !out.contains(v) { out.append(v) }
        }
        return out
    }

    // ------------------------------------------------------------ akcije

    /// Boje LED-a sa servera (app/tag/v1/getLedColor): parovi (vrednost, naziv).
    func ledColors() -> [(String, String)] {
        var out: [(String, String)] = []
        guard let r = try? api.app("app/tag/v1/getLedColor", body()) else { return out }
        let d = r["data"]
        let a: [Any] = (d as? [Any]) ?? Json.records(d)
        for (k, o) in a.enumerated() {
            if let j = o as? J {
                var v = ""
                for key in ["ledColor", "colorValue", "value", "code", "colorCode", "id", "key"] where v.isEmpty { v = Json.s(j, key) }
                var n = ""
                for key in ["ledColorName", "colorName", "translateName", "name", "label", "desc"] where n.isEmpty { n = Json.s(j, key) }
                if !v.isEmpty { out.append((v, n.isEmpty ? L.t("Boja ") + v : n)) }
            } else if !(o is NSNull) {
                out.append((String(k + 1), Json.str(o)))
            }
        }
        return out
    }

    /// Blink by item: boja (ledColor) i broj ciklusa (jedan ciklus = 200 ms upaljeno + 200 ms ugaseno).
    func ledForItem(_ itemId: String, color: Int = 2, cycles: Int = 10) throws {
        try api.app("app/tag/v1/ledForItem", ["itemId": itemId, "cycleCount": String(max(1, min(65535, cycles))),
                                               "ledColor": String(color), "ledIntervalTime": "200",
                                               "ledStayTime": "200", "loginId": loginId])
    }

    func ledForTag(_ tagId: String) throws {
        try api.app("app/tag/v1/ledForTagId", ["tagId": tagId, "cycleCount": "10", "ledColor": "2",
                                                "ledIntervalTime": "200", "ledStayTime": "200", "loginId": loginId])
    }

    func pushTag(_ tagId: String) throws {
        try api.app("app/tag/v1/pushTag", ["tagId": tagId])
    }
}
