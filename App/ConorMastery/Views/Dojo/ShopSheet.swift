import MasteryCore
import SwiftUI

struct ShopSheet: View {
    @Environment(MasteryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category: ItemCategory?
    @State private var treatName = ""
    @State private var treatPrice = 100

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    categoryChips
                    treatsCard
                    if let expansion = store.world.nextExpansion { landCard(expansion) }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in itemTile(item) }
                    }
                }
                .padding()
            }
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Label("\(store.grit)", systemImage: "seal.fill").foregroundStyle(Theme.gold) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var items: [ShopItem] {
        Catalog.items.filter { category == nil || $0.category == category }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip("All", selected: category == nil) { category = nil }
                ForEach(ItemCategory.allCases, id: \.self) { c in
                    chip(c.rawValue.capitalized, selected: category == c) { category = c }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(selected ? Theme.accent : .secondary)
    }

    /// Real-life rewards you price yourself (Habitica's custom rewards).
    private var treatsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Real-life treats").font(.headline)
            ForEach(store.settings.treats) { treat in
                HStack {
                    Text(treat.name)
                    Spacer()
                    Button { store.buy(treat: treat) } label: { Label("\(treat.price)", systemImage: "seal.fill") }
                        .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(store.grit < treat.price)
                }
                .swipeActions { Button("Delete", role: .destructive) { store.removeTreat(treat) } }
                .contextMenu { Button("Delete", role: .destructive) { store.removeTreat(treat) } }
            }
            HStack {
                TextField("New treat (e.g. cheat meal)", text: $treatName)
                Stepper("\(treatPrice)", value: $treatPrice, in: 10...2000, step: 10).fixedSize()
                Button("Add") { store.addTreat(name: treatName, price: treatPrice); treatName = "" }
                    .disabled(treatName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func landCard(_ expansion: (size: Int, price: Int)) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Expand land to \(expansion.size)x\(expansion.size)").font(.headline)
                Text("Room for more of your garden.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { store.expandLand() } label: { Label("\(expansion.price)", systemImage: "seal.fill") }
                .buttonStyle(.borderedProminent).tint(Theme.jade)
                .disabled(store.grit < expansion.price)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func itemTile(_ item: ShopItem) -> some View {
        let locked = store.level.level < item.minLevel
        let owned = store.world.inventory[item.id] ?? 0
        return VStack(spacing: 8) {
            Text(ItemArt.glyph(item.id)).font(.system(size: 52)).opacity(locked ? 0.35 : 1)
            Text(item.name).font(.subheadline.weight(.semibold))
            if owned > 0 { Text("\(owned) unplaced").font(.caption2).foregroundStyle(.secondary) }
            Button { store.buy(item) } label: {
                if locked { Label("Lvl \(item.minLevel)", systemImage: "lock.fill") }
                else { Label("\(item.price)", systemImage: "seal.fill") }
            }
            .buttonStyle(.borderedProminent)
            .tint(locked ? .gray : Theme.ink)
            .disabled(locked || store.grit < item.price)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
