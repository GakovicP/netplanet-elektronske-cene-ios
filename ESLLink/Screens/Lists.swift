import SwiftUI

struct ListRow {
    var title = "", sub = "", detail = "", badge = ""
    var badgeColor = UI.GREY
    var icon: Icon?
    var iconColor = UI.PRIMARY
    var data: Any?
}

struct PageResult {
    var rows: [ListRow] = []
    var total = -1
    var more = false
}

/// Zajednicka lista sa pretragom i ucitavanjem stranica (PagedListActivity).
struct PagedListView: View {
    let title: String
    var hasSearch = true
    var searchHint = "Pretraga"
    var rowIcon: Icon = .list
    var rowColor: Color = UI.PRIMARY
    var filterOptions: [String]? = nil
    /// (upit, strana, filter) – izvrsava se van glavne niti
    let load: (String, Int, Int) throws -> PageResult
    var onRow: (ListRow) -> Void = { _ in }

    @EnvironmentObject var app: AppState
    @State private var search = ""
    @FocusState private var focus: Int?
    @State private var rows: [ListRow] = []
    @State private var page = 1
    @State private var query = ""
    @State private var more = false
    @State private var summary = ""
    @State private var filter = 0
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            if hasSearch {
                ScanField(label: "", hint: searchHint, text: $search, focus: $focus, id: 1) { _ in reload() }
                    .card(radius: 18, padding: 12)
            }
            if let f = filterOptions {
                Dropdown(options: f, selection: Binding(get: { filter }, set: { v in
                    if v == filter { return }
                    filter = v
                    reload()
                })).padding(.top, 8)
            }
            T(summary, 13, UI.SUB).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        Button { onRow(r) } label: { rowView(r) }.buttonStyle(PressStyle())
                    }
                    if more {
                        FlatButton(title: "Učitaj još", color: UI.INK) { fetch(page + 1) }
                            .padding(.top, 8).padding(.bottom, 16)
                    }
                }.padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 12).padding(.top, 12)
        .chrome(title)
        .onAppear {
            if started { return }
            started = true
            reload()
        }
    }

    private func rowView(_ r: ListRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BadgeIcon(icon: r.icon ?? rowIcon, bg: r.icon != nil ? r.iconColor : rowColor, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    T(r.title, 17, UI.TEXT, true).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    if !r.badge.isEmpty { Chip(s: r.badge, bg: r.badgeColor) }
                }
                if !r.sub.isEmpty { T(r.sub, 15, UI.SUB).multilineTextAlignment(.leading) }
                if !r.detail.isEmpty { T(r.detail, 13, UI.GREY).multilineTextAlignment(.leading) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(UI.CARD).elevation(1))
        .padding(.horizontal, 1)
    }

    private func reload() {
        query = search.trimmed
        rows = []
        more = false
        fetch(1)
    }

    private func fetch(_ pg: Int) {
        let q = query, f = filter, load = self.load
        app.run({ try load(q, pg, f) }, done: { r in
            page = pg
            rows.append(contentsOf: r.rows)
            more = r.more
            summary = "Prikazano \(rows.count)" + (r.total >= 0 ? L.t(" od ") + "\(r.total)" : "")
            if rows.isEmpty { summary = "Nema rezultata" }
        })
    }
}

/// Polje "naziv: vrednost" u dijalozima sa detaljima.
struct DetailField: View {
    let k: String, v: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            T(k, 12, UI.SUB, true).padding(.top, 8)
            T(v, 16, UI.TEXT).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ================================================================ Item List

private final class Box<T> { var v: T; init(_ v: T) { self.v = v } }

struct ItemListView: View {
    @EnvironmentObject var app: AppState
    private static let SIZE = 50
    @State private var searchRes = Box<[Item]>([])

    static func row(_ it: Item) -> ListRow {
        var r = ListRow()
        r.title = it.code
        r.sub = it.name
        r.badge = it.bound ? "Linkovan" : "Nije linkovan"
        r.badgeColor = it.bound ? UI.OK : UI.GREY
        if !it.tags.isEmpty { r.detail = "ESL: " + it.tags }
        r.data = it
        return r
    }

    private var hint: String {
        guard let s = app.session?.server else { return "Pretraga" }
        var sb = "Pretraga: "
        if s.searchCode { sb += "Item code " }
        if s.searchName { sb += "Item name " }
        if !s.extraField.isEmpty { sb += s.extraFieldLabel.isEmpty ? s.extraField : s.extraFieldLabel }
        return sb.trimmed
    }

    var body: some View {
        let s = app.session!
        let box = searchRes
        PagedListView(title: "Item List", searchHint: hint, rowIcon: .cart, rowColor: UI.ACCENT, load: { q, page, _ in
            var r = PageResult()
            let size = ItemListView.SIZE
            if q.isEmpty {
                let p = try s.itemsPage(nil, 0, page, size)
                r.rows = p.items.map(ItemListView.row)
                r.total = p.total
                r.more = page * size < p.total && !p.items.isEmpty
            } else {
                if page == 1 { box.v = try s.searchItems(q) }
                let from = (page - 1) * size, to = min(box.v.count, page * size)
                if from < to { r.rows = box.v[from..<to].map(ItemListView.row) }
                r.total = box.v.count
                r.more = to < box.v.count
            }
            return r
        }, onRow: { r in
            if let it = r.data as? Item { showItem(it) }
        })
    }

    private func showItem(_ it: Item) {
        let s = app.session!
        app.run({ try s.eslsForItem(it.code) }, done: { esls in dialog(it, esls) }, fail: { _ in dialog(it, nil) })
    }

    private func dialog(_ it: Item, _ esls: [String]?) {
        let s = app.session!
        let e = esls == nil ? it.tags : esls!.joined(separator: ", ")
        var fields: [(String, String)] = [("Item code", it.code), ("Item name", it.name), ("Etikete", e.isEmpty ? "nije linkovan" : e)]
        for f in s.fields where f.column != "itemCode" && f.column != "itemName" {
            let v = it.field(f.column)
            if !v.isEmpty { fields.append((f.label, v)) }
        }
        let content = DialogScroll {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, kv in DetailField(k: kv.0, v: kv.1) }
            }.padding(.horizontal, 24).padding(.top, 8)
        }
        app.dialog(DialogSpec(title: it.code, content: AnyView(content), buttons: [
            DialogButton(title: "Blink", kind: .neutral, action: { BlinkItem.open(app, it) }),
            DialogButton(title: "Zatvori", kind: .positive),
        ]))
    }
}

// ================================================================ ESL List

enum EslRows {
    static func row(_ o: J) -> ListRow { row(Tag.from(o)) }

    static func row(_ t: Tag) -> ListRow {
        var r = ListRow()
        r.title = t.code
        let g = t.goodsSummary()
        r.sub = g.isEmpty ? "nije linkovana" : g
        var d = ""
        if !t.typeName.isEmpty { d += t.typeName }
        if !t.power.isEmpty { d += (d.isEmpty ? "" : " • ") + "Baterija " + t.power + " V" }
        if !t.lqi.isEmpty { d += " • Signal " + t.lqi }
        if !t.time.isEmpty { d += "\nPoslednja komunikacija: " + t.time }
        r.detail = d
        let st = t.connectivity.isEmpty ? t.state : t.connectivity
        r.badge = st
        let sl = st.lowercased()
        r.badgeColor = sl.contains("success") || sl.contains("online") ? UI.OK
            : sl.contains("fail") || sl.contains("offline") || sl.contains("inactive") ? UI.ERR : UI.GREY
        r.data = t
        return r
    }

    static func page(_ o: J, _ page: Int, _ size: Int) -> PageResult {
        var r = PageResult()
        let data = o["data"]
        let a = Json.records(data)
        r.rows = a.map(row)
        if let d = data as? J { r.total = Json.i(d, "total", -1) }
        r.more = a.count >= size && (r.total < 0 || page * size < r.total)
        return r
    }

    static func showTag(_ app: AppState, _ t: Tag) {
        let fields: [(String, String)] = [
            ("Tip", t.typeName), ("Status", t.state), ("Baterija", t.power.isEmpty ? "" : t.power + " V"),
            ("Signal (LQI)", t.lqi), ("Bazna stanica", t.mac), ("Poslednja komunikacija", t.time),
            ("Firmware", t.ver), ("Linkovano", t.goodsSummary().isEmpty ? "nije linkovana" : t.goodsSummary()),
        ].filter { !$0.1.isEmpty }
        let content = DialogScroll {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, kv in DetailField(k: kv.0, v: kv.1) }
            }.padding(.horizontal, 24).padding(.top, 8)
        }
        app.dialog(DialogSpec(title: "ESL " + t.code, content: AnyView(content), buttons: [
            DialogButton(title: "Osveži prikaz", kind: .negative, action: {
                guard let s = app.session else { return }
                app.run({ try s.pushTag(t.tagId) }, done: { _ in app.showToast("Poslat push zadatak") })
            }),
            DialogButton(title: "Unlink", kind: .positive, action: { app.open(.unlink(t.code)) }),
        ]))
    }
}

struct EslListView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        let s = app.session!
        PagedListView(title: "ESL List", searchHint: "ESL kod, item code ili naziv", rowIcon: .tag, rowColor: UI.GREY6E,
                      filterOptions: ["Sve etikete", "Linkovane", "Nelinkovane"], load: { q, page, f in
            let size = 50
            let o = try s.tagListRaw(q, f, page, size)
            if q.isEmpty { return EslRows.page(o, page, size) }
            // ako server ignorise filter, prikazi samo etikete koje odgovaraju pretrazi
            var r = PageResult()
            r.rows = Json.records(o["data"]).filter { Json.s($0, "tagIdentity").lowercased().contains(q.lowercased()) }.map { EslRows.row($0) }
            if r.rows.isEmpty && page == 1 {
                // tacan ESL kod (skenirana etiketa)
                if let t = try? s.getTag(q.trimmed) {
                    r.rows = [EslRows.row(t)]
                    r.total = 1
                    return r
                }
                // nije ESL kod – trazi etikete po artiklu (kod / naziv)
                for c in try s.eslCodesForItemSearch(q) {
                    if let t = try s.getTag(c) { r.rows.append(EslRows.row(t)) }
                    if r.rows.count >= size { break }
                }
            }
            r.total = r.rows.count
            r.more = false
            return r
        }, onRow: { r in
            if let t = r.data as? Tag { EslRows.showTag(app, t) }
        })
    }
}

/// Liste iz monitoringa: offline / slaba baterija / slab signal.
struct ProblemListView: View {
    let type: String
    @EnvironmentObject var app: AppState
    var body: some View {
        let s = app.session!
        let t = type
        PagedListView(title: t == "offline" ? "Offline etikete" : t == "weak" ? "Slab signal" : "Slaba baterija",
                      hasSearch: false, rowIcon: .error, rowColor: UI.WARN, load: { _, page, _ in
            EslRows.page(try s.problemList(t, page, 50), page, 50)
        }, onRow: { r in
            if let tg = r.data as? Tag { EslRows.showTag(app, tg) }
        })
    }
}

// ================================================================ APs

/// Bazne stanice (AP).
struct ApListView: View {
    @EnvironmentObject var app: AppState
    private static let SIZE = 50

    var body: some View {
        let s = app.session!
        PagedListView(title: "APs", searchHint: "MAC adresa", rowIcon: .wifi, rowColor: UI.GREY81,
                      filterOptions: ["Sve bazne stanice", "Online", "Offline"], load: { q, page, filter in
            var r = PageResult()
            let size = ApListView.SIZE
            func fetch(_ online: Int) throws -> J {
                var b: J = ["storeId": s.storeId, "online": String(online), "findBy": q.isEmpty ? "1" : "0",
                            "current": String(page), "size": String(size)]
                if !q.isEmpty { b["macAddress"] = q }
                return try s.api.app("app/coor/v1/getList", b)
            }
            func addRows(_ o: J) -> Int {
                let data = o["data"]
                for c in Json.records(data) {
                    var row = ListRow()
                    row.title = Json.s(c, "coorName").isEmpty ? Json.s(c, "macAddress") : Json.s(c, "coorName")
                    row.sub = "IP " + Json.s(c, "ipAddr") + " • MAC " + Json.s(c, "macAddress")
                    row.detail = "Etiketa: " + Json.s(c, "bindTags") + " • Verzija " + Json.s(c, "ver") + "\nPoslednja veza: " + Json.s(c, "coorTime")
                    let on = Json.s(c, "coorState") == "901"
                    row.badge = Json.s(c, "coorStateDesc").isEmpty ? (on ? "Online" : "Offline") : Json.s(c, "coorStateDesc")
                    row.badgeColor = on ? UI.OK : UI.ERR
                    row.icon = .wifi
                    row.iconColor = on ? UI.OK : UI.ERR
                    r.rows.append(row)
                }
                return (data as? J).map { Json.i($0, "total", -1) } ?? -1
            }
            if filter == 0 {
                // sve: online + offline (vecina prodavnica ima malo AP-ova)
                let t1 = addRows(try fetch(901))
                let t2 = addRows(try fetch(902))
                r.total = t1 >= 0 && t2 >= 0 ? t1 + t2 : -1
                r.more = t1 > page * size || t2 > page * size
            } else {
                r.total = addRows(try fetch(filter == 1 ? 901 : 902))
                r.more = r.total > page * size
            }
            return r
        })
    }
}
