import SwiftUI
import FoundationModels

// Что ИИ возвращает, когда оценивает еду по описанию
@Generable
struct FoodEstimate {
    @Guide(description: "Short name of the food, 1-4 words")
    let name: String

    @Guide(description: "Calories for the whole described amount, kcal", .range(0...5000))
    let calories: Int

    @Guide(description: "Protein for the whole amount, grams", .range(0...300))
    let protein: Int

    @Guide(description: "Fat for the whole amount, grams", .range(0...300))
    let fat: Int

    @Guide(description: "Carbohydrates for the whole amount, grams", .range(0...600))
    let carbs: Int

    @Guide(description: "Dietary fiber for the whole amount, grams", .range(0...100))
    let fiber: Int
}

// Добавить еду в дневник за выбранный день
struct AddFoodView: View {
    let date: Date

    @Environment(HealthStore.self) private var health
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var isEstimating = false
    @State private var estimateError: String?

    @State private var name = ""
    @State private var calories = 0
    @State private var protein = 0
    @State private var fat = 0
    @State private var carbs = 0
    @State private var fiber = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                        .font(.subheadline.bold())
                        .kerning(1)
                        .foregroundStyle(Theme.green.opacity(0.8))
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.green)
                        .buttonStyle(.plain)
                }

                Text("Add food")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.dark)

                // ---------- ИИ ----------
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI CHEF")
                        .font(.caption.bold())
                        .kerning(1)
                        .foregroundStyle(Theme.chefLabel)
                    Text("Describe what you ate and how much, and I'll estimate it.")
                        .foregroundStyle(.white)

                    TextField("e.g. Oatmeal with banana, 300 g", text: $description, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.dark)
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))

                    if let estimateError {
                        Text(estimateError)
                            .font(.subheadline)
                            .foregroundStyle(Theme.chefLabel)
                    }

                    Button {
                        Task { await estimate() }
                    } label: {
                        HStack(spacing: 8) {
                            if isEstimating {
                                ProgressView().tint(Theme.dark)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isEstimating ? "Estimating…" : "Estimate with AI")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.dark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.chefLabel, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || isEstimating)
                }
                .padding(20)
                .background(Theme.dark, in: RoundedRectangle(cornerRadius: 24))

                // ---------- Вручную ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "OR ENTER MANUALLY")
                    VStack(spacing: 12) {
                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Theme.dark)
                            .padding(12)
                            .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
                        numberRow("Calories", $calories, "kcal")
                        numberRow("Protein", $protein, "g")
                        numberRow("Fat", $fat, "g")
                        numberRow("Carbs", $carbs, "g")
                        numberRow("Fiber", $fiber, "g")
                    }
                    .card()
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Add to diary") { save() }
                .disabled(calories == 0)
                .opacity(calories == 0 ? 0.5 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(Theme.background)
        }
    }

    func numberRow(_ label: String, _ value: Binding<Int>, _ unit: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.dark)
            Spacer()
            // Пустое поле вместо "0", чтобы цифры не дописывались к нулю
            TextField("0", text: Binding(
                get: { value.wrappedValue == 0 ? "" : String(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.filter(\.isNumber).prefix(5)) ?? 0 }
            ))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .bold()
                .foregroundStyle(Theme.dark)
                .frame(width: 80)
                .numberKeyboard()
            Text(unit)
                .foregroundStyle(.gray)
                .frame(width: 36, alignment: .leading)
        }
    }

    func save() {
        // Для прошлого дня ставим время на полдень, для сегодня — сейчас
        let time = Calendar.current.isDateInToday(date)
            ? Date.now
            : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        health.add(FoodEntry(
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Food" : name,
            calories: calories, protein: protein, fat: fat, carbs: carbs, fiber: fiber,
            date: time
        ), on: date)
        dismiss()
    }

    func estimate() async {
        estimateError = nil
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            estimateError = aiUnavailableMessage(availability)
            return
        }

        isEstimating = true
        defer { isEstimating = false }

        let session = LanguageModelSession(instructions: """
        You are a nutrition expert. Estimate realistic nutrition for the food and amount the user describes.
        If no amount is given, assume one normal portion.
        """)

        do {
            let response = try await session.respond(
                to: description,
                generating: FoodEstimate.self,
                options: GenerationOptions(temperature: 0.2)
            )
            let food = response.content
            name = food.name
            calories = food.calories
            protein = food.protein
            fat = food.fat
            carbs = food.carbs
            fiber = food.fiber
        } catch {
            print("AI error:", error)
            estimateError = "Couldn't estimate that. Try describing it in English, with the amount."
        }
    }
}

extension View {
    // Цифровая клавиатура (только на iPhone/iPad)
    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

#Preview {
    AddFoodView(date: .now)
        .environment(HealthStore())
}
