import SwiftUI

// Шаг 2 настройки: что есть на кухне. Здесь же весь выбор сохраняется на устройстве
struct KitchenView: View {
    let diet: Set<String>
    let restrictions: Set<String>
    let finishTitle: String
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedAppliances = Prefs.appliances
    @State private var selectedTools = Prefs.tools

    let appliances = ["Stovetop", "Oven", "Microwave", "Air fryer", "Multicooker", "Rice Cooker",
                      "Blender", "Mixer", "Toaster", "Grill", "Juicer", "Dehydrator"]
    let tools = ["Frying pan", "Saucepan", "Knife & board", "Baking dish"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: 2,
                    total: 2,
                    title: "What's in your kitchen?",
                    subtitle: "We'll only suggest what you can actually cook"
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "APPLIANCES")
                    FlowLayout(spacing: 8) {
                        ForEach(appliances, id: \.self) { ChoiceChip(title: $0, selection: $selectedAppliances) }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "COOKWARE & TOOLS")
                    FlowLayout(spacing: 8) {
                        ForEach(tools, id: \.self) { ChoiceChip(title: $0, selection: $selectedTools) }
                    }
                    Text("The basics are pre-selected, tap to change")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                SecondaryButton(title: "Back") { dismiss() }
                PrimaryButton(title: finishTitle) { saveAndFinish() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(Theme.background)
        }
    }

    func saveAndFinish() {
        Prefs.diet = diet
        Prefs.restrictions = restrictions
        Prefs.appliances = selectedAppliances
        Prefs.tools = selectedTools
        onFinish()
    }
}

#Preview {
    NavigationStack {
        KitchenView(diet: ["Vegan"], restrictions: [], finishTitle: "Show recipes") {}
    }
}
