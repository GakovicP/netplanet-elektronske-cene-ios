import SwiftUI
import GameController

struct LinkView: View {
    @EnvironmentObject var app: AppState
    private enum F: Hashable { case esl, item }

    @State private var multi = Prefs.ui.bool(forKey: "multi")
    @State private var eslText = ""
    @State private var itemText = ""
    @FocusState private var focus: F?

    // zajednicko
    @State private var tag: Tag?
    @State private var layouts: [Layout] = []
    @State private var layout: Layout?
    @State private var eslInfo: String?
    @State private var eslDone = false
    @State private var autoLink = true

    // obican link
    @State private var item: Item?
    @State private var itemDone = false

    // multilink
    private struct Slot { var item: Item?; var existing = false }
    @State private var slots: [Slot] = []
    @State private var selectedSlot = -1
    @State private var prefillPos: [Int]?

    private var S: Session { app.session! }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Link / Multilink
                HStack(spacing: 0) {
                    tab("Link", .link, !multi) { setMode(false) }
                    tab("Multilink", .multi, multi) { setMode(true) }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 16).fill(UI.TAB_BG))

                VStack(spacing: 12) {
                    if multi { multiContent } else { linkContent }
                }.padding(.top, 12)
            }.padding(14)
        }
        .scrollDismissesKeyboard(.interactively)
        .chrome(multi ? "Multilink" : "Link")
        .onAppear {
            if app.session == nil { return }
            autoLink = S.server.autoLink
        }
    }

    private func tab(_ t: String, _ icon: Icon, _ sel: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 8) {
                IconView(icon: icon, color: sel ? UI.PRIMARY : UI.SUB).frame(width: 20, height: 20)
                Text(t).font(.ui(16, true)).foregroundColor(sel ? UI.PRIMARY : UI.SUB)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(sel ? RoundedRectangle(cornerRadius: 12).fill(Color.white).elevation(2) : nil)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    // ================================================================ zajednicko

    private var eslCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScanField(label: "Barkod etikete", hint: "Skeniraj ili ukucaj ESL", text: $eslText, focus: $focus, id: F.esl) { onEsl($0) }
                .padding(.top, 14)
            if let info = eslInfo {
                // vec linkovana etiketa: zelenkasta pozadina
                let linked = !(tag?.goodsSummary().isEmpty ?? true)
                Text(L.t(info)).font(.ui(14)).foregroundColor(UI.TEXT).lineSpacing(2)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(linked ? Color(argb: 0xFFE3F4E5) : UI.SOFT))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(linked ? UI.OK.opacity(0.45) : Color.clear, lineWidth: 1))
                    .padding(.top, 10)
            }
        }
    }

    private var autoBox: some View {
        CheckBox(text: multi ? "Automatski Multilink kada se popune sva polja" : "Automatski link čim su skenirani etiketa i proizvod",
                 on: Binding(get: { autoLink }, set: { c in
                     autoLink = c
                     S.server.autoLink = c
                     ServerStore().save(S.server)
                 }))
            .padding(.top, -4)
    }

    private func setMode(_ m: Bool) {
        multi = m
        Prefs.ui.set(m, forKey: "multi")
        tag = nil; layout = nil; item = nil; layouts = []; slots = []; selectedSlot = -1
        eslText = ""; itemText = ""; eslInfo = nil; eslDone = false; itemDone = false
        focus = nil   // bez automatskog otvaranja tastature
    }

    private func error(_ m: String) {
        UI.beepErr()
        app.status(m, UI.ERR)
    }

    private func onEsl(_ raw: String) {
        let code = eslCode(raw)
        if code != raw.trimmed { eslText = code }
        let multi = self.multi
        let s = S
        app.run({ () -> (Tag?, [Layout], [Int]?) in
            guard let t = try s.getTag(code) else { return (nil, [], nil) }
            var ls = try s.layoutsFor(t, multi)
            var pos: [Int]?
            if multi && !t.bindings.isEmpty && !ls.isEmpty {
                // postojeci artikli: trenutni layout etikete i pozicija svakog artikla
                var cur = ls[0]
                for l in ls where l.id == t.layoutId { cur = l }
                ls.removeAll { $0 === cur }
                ls.insert(cur, at: 0)
                let lt = (try? s.layoutItemTags(cur)) ?? []
                let n = max(1, cur.slots())
                var used = [Bool](repeating: false, count: max(n, t.bindings.count))
                var pp: [Int] = []
                for bd in t.bindings {
                    var p = bd.itemTagStr.isEmpty ? -1 : (lt.firstIndex(of: bd.itemTagStr) ?? -1)
                    if p < 0 && bd.itemTag >= 1 && bd.itemTag <= n { p = bd.itemTag - 1 }
                    if p < 0 || p >= used.count || used[p] { p = used.firstIndex(of: false) ?? -1 }
                    pp.append(p)
                    if p >= 0 { used[p] = true }
                }
                pos = pp
            }
            return (t, ls, pos)
        }, done: { r in
            guard let t = r.0 else {
                tag = nil
                eslDone = false
                error("Skenirana etiketa ne postoji")
                eslInfo = nil
                eslText = ""
                refocus(.esl)
                return
            }
            if r.1.isEmpty {
                tag = nil
                error("Layout ne postoji")
                eslInfo = "ESL " + t.code + " • " + t.typeName
                eslText = ""
                refocus(.esl)
                return
            }
            tag = t
            layouts = r.1
            layout = r.1[0]
            prefillPos = r.2
            UI.beepOk()
            if multi { onEslMultiReady() } else { onEslLinkReady() }
        })
    }

    /// Fokus za Bluetooth skener (hardverska tastatura); bez nje se tastatura ne otvara sama.
    private func refocus(_ f: F) {
        if focus == f { focus = nil }
        guard GCKeyboard.coalesced != nil else { focus = nil; return }
        DispatchQueue.main.async { focus = f }
    }

    private func eslDesc() -> String {
        guard let tag = tag else { return "" }
        var sb = "ESL " + tag.code
        if !tag.typeName.isEmpty { sb += " • " + tag.typeName }
        if !multi, let l = layout { sb += "\nLayout: " + l.title }
        let g = tag.goodsSummary()
        sb += "\nTrenutno: " + (g.isEmpty ? "nije linkovana" : g)
        return sb
    }

    private func onItem(_ q: String) {
        let s = S
        app.run({ try s.searchItems(q) }, done: { res in
            if res.isEmpty {
                error("Proizvod nije pronađen: " + q)
                itemText = ""
                refocus(.item)
                return
            }
            ItemPicker.pick(app, q, res) { it in
                if multi { addToSlot(it) } else { setItem(it) }
            }
        })
    }

    // ================================================================ obican link

    @ViewBuilder private var linkContent: some View {
        TitledCard(icon: .tag, color: UI.PRIMARY, title: "1. Etiketa", sub: "Skeniraj ESL etiketu", done: eslDone) {
            eslCardContent
        }
        TitledCard(icon: .cart, color: Color(argb: 0xFFF57921), title: "2. Proizvod", sub: "Skeniraj ili pretraži artikal", done: itemDone) {
            VStack(alignment: .leading, spacing: 0) {
                ScanField(label: "Proizvod", hint: "Item code / naziv / barkod", text: $itemText, focus: $focus, id: F.item) { onItem($0) }
                    .padding(.top, 14)
                if let it = item {
                    VStack(alignment: .leading, spacing: 0) {
                        Caption("Item code")
                        T(it.code, 24, UI.TEXT, true)
                        Caption("Item name").padding(.top, 8)
                        T(it.name.isEmpty ? "—" : it.name, 16, UI.SUB)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(UI.SOFT))
                    .padding(.top, 12)
                }
            }
        }
        PrimaryButton(title: "Linkuj", color: UI.OK, icon: .link) { doLink() }
        FlatButton(title: "Očisti", color: UI.PRIMARY) { resetLink() }.padding(.top, -4)
        autoBox
    }

    private func resetLink() {
        tag = nil; layout = nil; item = nil
        eslText = ""; itemText = ""
        eslInfo = nil
        eslDone = false; itemDone = false
        refocus(.esl)
    }

    private func onEslLinkReady() {
        eslDone = true
        eslInfo = eslDesc()
        if item != nil && S.server.autoLink { doLink() } else { refocus(.item) }
    }

    private func setItem(_ it: Item) {
        item = it
        itemText = it.code
        itemDone = true
        if tag == nil {
            app.status("Skeniraj etiketu", UI.WARN)
            refocus(.esl)
        } else if S.server.autoLink {
            doLink()
        }
    }

    private func doLink() {
        guard let t = tag else { error("Skeniraj etiketu"); refocus(.esl); return }
        guard let it = item else { error("Skeniraj proizvod"); refocus(.item); return }
        guard let l = layout else { return }
        let s = S
        app.run({ try s.link(t, l, [it], nil) }, done: { _ in
            UI.beepOk()
            app.status("Linkovano ✓\nESL " + t.code + "  →  " + it.code + "\n" + it.name, UI.OK)
            resetLink()
        }, fail: { e in error("Link nije uspeo:\n" + errMsg(e) + "\n(dodirni za detalje)") })
    }

    // ================================================================ multilink

    @ViewBuilder private var multiContent: some View {
        TitledCard(icon: .tag, color: UI.PRIMARY, title: "1. Etiketa", sub: "Split-screen / self adapt", done: eslDone) {
            VStack(alignment: .leading, spacing: 0) {
                eslCardContent
                if tag != nil && layouts.count > 1 {
                    Dropdown(options: layouts.map { $0.title + " – \($0.slots()) polja" },
                             selection: Binding(get: { layouts.firstIndex { $0 === layout } ?? 0 }, set: { i in
                                 if i >= 0 && i < layouts.count && layouts[i] !== layout {
                                     layout = layouts[i]
                                     resizeSlots()
                                 }
                             }))
                        .padding(.top, 10)
                }
            }
        }
        TitledCard(icon: .cart, color: Color(argb: 0xFFF57921), title: "2. Proizvodi", sub: "Popuni polja na etiketi") {
            VStack(alignment: .leading, spacing: 0) {
                ScanField(label: "Proizvod za sledeće polje", hint: "Item code / naziv / barkod", text: $itemText, focus: $focus, id: F.item) { v in
                    if tag == nil { error("Prvo skeniraj etiketu"); itemText = ""; refocus(.esl); return }
                    onItem(v)
                }.padding(.top, 14)
                slotList.padding(.top, 6)
            }
        }
        PrimaryButton(title: "Multilink", color: UI.OK, icon: .multi) { doMulti() }
        FlatButton(title: "Očisti", color: UI.PRIMARY) { resetMulti() }.padding(.top, -4)
        autoBox
    }

    @ViewBuilder private var slotList: some View {
        if tag != nil, let l = layout {
            let next = nextEmpty()
            VStack(alignment: .leading, spacing: 8) {
                Caption("Layout: " + l.title).padding(.top, 8)
                ForEach(Array(slots.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 12) {
                        NumBadge(n: i + 1, color: s.item != nil ? UI.OK : i == next ? UI.ACCENT : UI.GREY, size: 34, font: 16)
                        VStack(alignment: .leading, spacing: 0) {
                            if let it = s.item {
                                if i == next { T("← skeniraj novi proizvod za ovo polje", 13, UI.ACCENT, true) }
                                T(it.code, 18, UI.TEXT, true)
                                T(it.name, 14, UI.SUB)
                                if s.existing { T("već linkovan – dodirni za zamenu", 12, UI.GREY) }
                            } else {
                                T(i == next ? "← skeniraj proizvod" : "prazno", 15, UI.GREY)
                            }
                        }
                        Spacer(minLength: 0)
                        if s.item != nil {
                            Button {
                                slots[i].item = nil
                                slots[i].existing = false
                                selectedSlot = i
                                refocus(.item)
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 17, weight: .medium)).foregroundColor(UI.SUB)
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .padding(12)
                    .background(slotBG(i, s, next))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSlot = i
                        refocus(.item)
                    }
                }
            }
        }
    }

    @ViewBuilder private func slotBG(_ i: Int, _ s: Slot, _ next: Int) -> some View {
        if i == next {
            RoundedRectangle(cornerRadius: 14).fill(UI.SOFT).overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.ACCENT, lineWidth: 2))
        } else if s.item != nil {
            RoundedRectangle(cornerRadius: 14).fill(UI.SOFT)
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.LINE, lineWidth: 1))
        }
    }

    private func resetMulti() {
        tag = nil; layout = nil; layouts = []; slots = []; selectedSlot = -1
        eslText = ""; itemText = ""
        eslInfo = nil
        eslDone = false
        refocus(.esl)
    }

    private func onEslMultiReady() {
        eslInfo = eslDesc()
        eslDone = true
        slots = []
        let pos = prefillPos
        prefillPos = nil
        if let pos = pos, let t = tag, let l = layout {
            var need = l.slots()
            for p in pos { need = max(need, p + 1) }
            while slots.count < need { slots.append(Slot()) }
            for (k, p) in pos.enumerated() where p >= 0 && k < t.bindings.count {
                let bd = t.bindings[k]
                var it = Item()
                it.code = bd.itemCode
                it.name = bd.itemName
                slots[p].item = it
                slots[p].existing = true
            }
        }
        resizeSlots()
        if pos != nil { app.showToast("Etiketa već ima artikle – dodirni polje da ga zameniš") }
        refocus(.item)
    }

    private func resizeSlots() {
        let n = max(1, layout?.slots() ?? 1)
        while slots.count < n { slots.append(Slot()) }
        while slots.count > n { slots.removeLast() }
        selectedSlot = -1
    }

    private func nextEmpty() -> Int {
        if selectedSlot >= 0 && selectedSlot < slots.count { return selectedSlot } // izabrano polje (i popunjeno – zamena)
        return slots.firstIndex { $0.item == nil } ?? -1
    }

    private func addToSlot(_ it: Item) {
        if slots.enumerated().contains(where: { $0.offset != selectedSlot && $0.element.item?.code.lowercased() == it.code.lowercased() }) {
            error("Proizvod " + it.code + " je već u polju")
            itemText = ""
            refocus(.item)
            return
        }
        let idx = nextEmpty()
        if idx < 0 { error("Sva polja su popunjena"); itemText = ""; return }
        place(idx, it)
    }

    private func place(_ idx: Int, _ it: Item) {
        guard idx < slots.count else { return }
        slots[idx].item = it
        slots[idx].existing = false
        selectedSlot = -1
        itemText = ""
        UI.beepOk()
        if nextEmpty() >= 0 {
            refocus(.item) // odmah skener za sledece polje
        } else if S.server.autoLink {
            doMulti()
        }
    }

    private func doMulti() {
        guard let t = tag, let l = layout else { error("Skeniraj etiketu"); refocus(.esl); return }
        var codes: [String] = []
        var idx: [Int] = []
        var filled: [Slot] = []
        for (i, s) in slots.enumerated() where s.item != nil {
            codes.append(s.item!.code)
            idx.append(i)
            filled.append(s)
        }
        if codes.isEmpty { error("Skeniraj bar jedan proizvod"); refocus(.item); return }
        let s = S
        // Multilink nikad ne odvezuje: samo linkuje popunjena polja
        app.run({ try s.link(t, l, filled.map { $0.item! }, idx) }, done: { _ in
            UI.beepOk()
            app.status("Multilink uspešan ✓\nESL " + t.code + ": " + codes.joined(separator: ", "), UI.OK)
            resetMulti()
        }, fail: { e in error("Multilink nije uspeo:\n" + errMsg(e) + "\n(dodirni za detalje)") })
    }
}
