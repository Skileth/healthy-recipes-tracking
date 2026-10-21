import SwiftUI

// Шаг 1 настройки: как вы едите. Показывается при первом запуске и по кнопке "Edit setup"
struct ContentView: View {
    var isEditing = false            // true — открыт из "Edit setup"
    let onFinish: () -> Void         // вызывается после "Save" на втором шаге

    @Environment(\.dismiss) private var dismiss

    @State private var goToKitchen = false
    @State private var selectedDiet = Prefs.diet
    @State private var selectedRestrictions = Prefs.restrictions

    let items = ["I eat everything", "Vegan", "Vegetarian", "Pescatarian", "Raw foodist"]
    let pick = ["Lactose-free", "Dairy-free", "Gluten-free", "Wheat-free", "Nut-free", "Egg-free",
                "Soy-free", "Fish-free", "Shellfish-free", "Sesame-free", "Sugar-free"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    StepHeader(
                        step: 1,
                        total: 2,
                        title: isEditing ? "Edit your setup" : "Let's find what to cook",
                        subtitle: "Set it up once, we'll remember it",
                        trailingLabel: isEditing ? "Cancel" : nil
                    ) {
                        dismiss()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "HOW DO YOU EAT?")
                        FlowLayout(spacing: 8) {
                            ForEach(items, id: \.self) { ChoiceChip(title: $0, selection: $selectedDiet) }
                        }

                        Text("Restrictions, pick any")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .padding(.top, 8)
                        FlowLayout(spacing: 8) {
                            ForEach(pick, id: \.self) { ChoiceChip(title: $0, selection: $selectedRestrictions) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue") {
                    goToKitchen = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(Theme.background)
            }
            .navigationDestination(isPresented: $goToKitchen) {
                KitchenView(
                    diet: selectedDiet,
                    restrictions: selectedRestrictions,
                    finishTitle: isEditing ? "Save" : "Show recipes",
                    onFinish: onFinish
                )
            }
        }
    }
}

// Раскладка: кнопки в строку с переносом
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, totalWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            // +0.5 — запас на округление, иначе последняя кнопка в ровно заполненном ряду "уезжает" вниз
            if x + size.width > bounds.maxX + 0.5, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ContentView {}
}
