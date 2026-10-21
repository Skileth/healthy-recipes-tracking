import SwiftUI
import FoundationModels

// Что передаём с экрана списка на экран полного рецепта
struct RecipePick: Hashable, Identifiable {
    var id: String { title }
    let title: String
    let time: String
    let colorIndex: Int
    let equipmentUsed: [String]
    let mainIngredients: [String]
}

// MARK: - Что ИИ должен вернуть (полная версия рецепта)

@Generable
struct Ingredient {
    @Guide(description: "Ingredient name, may include how it's prepared, e.g. 'Sweet potato, diced'")
    let name: String

    @Guide(description: "Amount for 2 servings as a number. Use 0 if it's 'to taste'")
    let amount: Double

    @Guide(description: "Unit like 'g', 'ml', 'tbsp', 'tsp', 'clove', 'large', 'handfuls', or empty string for whole pieces")
    let unit: String

    @Guide(description: "If this ingredient replaces a usual one to fit the diet, write 'swapped for X' where X is the replaced ingredient. Otherwise empty string")
    let swapNote: String
}

@Generable
struct CookingStep {
    @Guide(description: "Short step title, 2-4 words")
    let title: String

    @Guide(description: "One or two sentences explaining exactly what to do")
    let details: String

    @Guide(description: "How many minutes this step takes", .range(1...120))
    let minutes: Int

    @Guide(description: "Main equipment for this step, one or two lowercase words like 'oven' or 'frying pan', or empty string")
    let equipment: String
}

@Generable
struct Nutrition {
    @Guide(description: "Weight of ONE cooked serving in grams", .range(50...1500))
    let servingWeight: Int

    @Guide(description: "Calories per serving, kcal", .range(30...2000))
    let calories: Int

    @Guide(description: "Protein per serving, grams", .range(0...200))
    let protein: Int

    @Guide(description: "Fat per serving, grams", .range(0...200))
    let fat: Int

    @Guide(description: "Carbohydrates per serving, grams", .range(0...300))
    let carbs: Int

    @Guide(description: "Dietary fiber per serving, grams", .range(0...80))
    let fiber: Int
}

@Generable
struct FullRecipe {
    @Guide(description: "How hard the recipe is", .anyOf(["Easy", "Medium", "Hard"]))
    let difficulty: String

    @Guide(description: "Only the tools actually used in the steps below, from the available list. As few as possible", .count(1...4))
    let tools: [String]

    @Guide(description: "All ingredients for 2 servings", .count(4...12))
    let ingredients: [Ingredient]

    @Guide(description: "Estimated nutrition for ONE serving, calculated from the ingredients above divided by 2")
    let nutrition: Nutrition

    @Guide(description: "If any ingredient was swapped to fit the diet or restrictions, one or two sentences explaining the swap. Otherwise empty string")
    let swapExplanation: String

    @Guide(description: "Cooking steps in order", .count(3...7))
    let steps: [CookingStep]
}

// MARK: - Экран полного рецепта

struct RecipeDetailView: View {
    let pick: RecipePick
    let dietTags: [String]
    let restrictionTags: [String]
    let equipment: Set<String>

    @Environment(\.dismiss) private var dismiss

    @State private var recipe: FullRecipe.PartiallyGenerated?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var servings = 2
    @State private var showCooking = false
    @Environment(HealthStore.self) private var health

    let baseServings = 2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                photoHeader

                VStack(alignment: .leading, spacing: 24) {
                    titleBlock

                    if let errorText {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(errorText).foregroundStyle(.gray)
                            Button("Try again") { Task { await load() } }
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.green)
                                .buttonStyle(.plain)
                        }
                    } else if recipe == nil {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Writing the full recipe…")
                                .foregroundStyle(.gray)
                        }
                    }

                    RecipeToolsSection(tools: recipe?.tools ?? [])
                    ingredientsSection
                    NutritionSection(nutrition: recipe?.nutrition, servings: servings)
                    swapCard
                    stepsSection
                }
                .padding(20)
            }
        }
        .background(Theme.background)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) { startButton }
        .sheet(isPresented: $showCooking) {
            CookingModeView(title: pick.title, steps: finishedSteps, canLog: recipe?.nutrition?.calories != nil) { eaten in
                logServings(eaten)
            }
        }
        .task {
            if recipe == nil { await load() }
        }
    }

    // MARK: - Части экрана

    var photoHeader: some View {
        ZStack(alignment: .topLeading) {
            Theme.cardColors[pick.colorIndex % Theme.cardColors.count]
                .frame(height: 260)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                )

            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.dark)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 60)
        }
    }

    var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pick.title)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Theme.dark)

            Text("\(pick.time) · \(servings) servings\(totalWeightText) · \(recipe?.difficulty ?? "…")")
                .foregroundStyle(.gray)

            FlowLayout(spacing: 6) {
                ForEach(dietTags + restrictionTags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.green, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    @ViewBuilder
    var ingredientsSection: some View {
        if let ingredients = recipe?.ingredients, !ingredients.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle("INGREDIENTS")
                    Spacer()
                    servingsStepper
                }

                VStack(spacing: 0) {
                    ForEach(ingredients.indices, id: \.self) { i in
                        let ing = ingredients[i]
                        HStack(spacing: 8) {
                            Text(ing.name ?? "")
                                .foregroundStyle(Theme.dark)
                            if let note = ing.swapNote, !note.isEmpty {
                                Text(note)
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.lightGreen, in: Capsule())
                            }
                            Spacer()
                            Text(amountText(ing))
                                .bold()
                                .foregroundStyle(Theme.dark)
                        }
                        .padding(.vertical, 12)

                        if i < ingredients.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    var servingsStepper: some View {
        HStack(spacing: 14) {
            Button {
                if servings > 1 { servings -= 1 }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)

            Text("\(servings) servings")
                .bold()
                .monospacedDigit()

            Button {
                if servings < 12 { servings += 1 }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.dark)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white, in: Capsule())
    }

    @ViewBuilder
    var swapCard: some View {
        if let swap = recipe?.swapExplanation, !swap.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI CHEF SWAP")
                    .font(.caption.bold())
                    .kerning(1)
                    .foregroundStyle(Theme.chefLabel)
                Text(swap)
                    .foregroundStyle(.white)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.dark, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    @ViewBuilder
    var stepsSection: some View {
        if let steps = recipe?.steps, !steps.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("STEPS")

                ForEach(steps.indices, id: \.self) { i in
                    let step = steps[i]
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(i + 1)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Theme.green, in: Circle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.title ?? "…")
                                .bold()
                                .foregroundStyle(Theme.dark)
                            if let details = step.details {
                                Text(details)
                                    .foregroundStyle(.gray)
                            }
                            let chip = stepChip(step)
                            if !chip.isEmpty {
                                Text(chip)
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.dark.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.beige, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
    }

    // Записать съеденные порции в дневник за сегодня
    func logServings(_ count: Int) {
        guard let n = recipe?.nutrition, let calories = n.calories else { return }
        health.add(FoodEntry(
            name: count == 1 ? pick.title : "\(pick.title) ×\(count)",
            calories: calories * count,
            protein: (n.protein ?? 0) * count,
            fat: (n.fat ?? 0) * count,
            carbs: (n.carbs ?? 0) * count,
            fiber: (n.fiber ?? 0) * count
        ), on: .now)
    }

    var startButton: some View {
        Button {
            showCooking = true
        } label: {
            Text("Start cooking")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.green, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading || finishedSteps.isEmpty)
        .opacity(isLoading || finishedSteps.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .kerning(1)
            .foregroundStyle(Theme.green)
    }

    // MARK: - Помощники

    // Пересчёт количества под число порций
    func amountText(_ ing: Ingredient.PartiallyGenerated) -> String {
        guard let amount = ing.amount else { return "" }
        let unit = ing.unit ?? ""
        if amount <= 0 { return unit.isEmpty ? "to taste" : unit }
        let scaled = amount * Double(servings) / Double(baseServings)
        let number = scaled.rounded() == scaled
            ? String(Int(scaled))
            : String(format: "%.1f", scaled)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    // Вес всего блюда на выбранное число порций, например " (900 g)"
    var totalWeightText: String {
        guard let weight = recipe?.nutrition?.servingWeight else { return "" }
        return " (\(weight * servings) g)"
    }

    func stepChip(_ step: CookingStep.PartiallyGenerated) -> String {
        var parts: [String] = []
        if let minutes = step.minutes { parts.append("\(minutes) min") }
        if let eq = step.equipment, !eq.isEmpty { parts.append(eq) }
        return parts.joined(separator: " · ")
    }

    var finishedSteps: [(title: String, details: String)] {
        (recipe?.steps ?? []).compactMap { step in
            guard let title = step.title, let details = step.details else { return nil }
            return (title, details)
        }
    }
    
    // MARK: - Запрос к ИИ

    func load() async {
        isLoading = true
        errorText = nil
        recipe = nil
        defer { isLoading = false }

        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            errorText = aiUnavailableMessage(availability)
            return
        }

        let session = LanguageModelSession(instructions: """
        You are a friendly AI chef inside a cooking app. Write clear, realistic home recipes.
        Diet: \(dietTags.isEmpty ? "no preference" : dietTags.joined(separator: ", "))
        Restrictions: \(restrictionTags.isEmpty ? "none" : restrictionTags.joined(separator: ", "))
        Kitchen equipment available: \(equipment.isEmpty ? "almost nothing" : equipment.joined(separator: ", "))
        Strictly follow the diet and restrictions and use ONLY the listed equipment.
        \(chefRules)
        """)

        let prompt = """
        Write the full recipe for "\(pick.title)" for 2 servings.
        It should take about \(pick.time.isEmpty ? "30 min" : pick.time).
        Use only this equipment for the cooking: \(pick.equipmentUsed.joined(separator: ", ")).
        Main ingredients: \(pick.mainIngredients.joined(separator: ", ")).
        """

        do {
            let stream = session.streamResponse(
                to: prompt,
                generating: FullRecipe.self,
                options: GenerationOptions(temperature: 0.5)
            )
            for try await snapshot in stream {
                recipe = snapshot.content
            }
        } catch {
            print("AI error:", error)
            errorText = "Couldn't write the recipe. \(error.localizedDescription)"
        }
    }
}

private struct RecipeToolsSection: View {
    let tools: [String]

    var body: some View {
        if !tools.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("TOOLS")
                    .font(.caption.bold())
                    .kerning(1)
                    .foregroundStyle(Theme.green)

                FlowLayout(spacing: 8) {
                    ForEach(tools, id: \.self) { tool in
                        Label(tool, systemImage: "wrench.and.screwdriver")
                            .font(.subheadline)
                            .foregroundStyle(Theme.dark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.beige, in: Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Режим готовки: по одному шагу на экране

struct CookingModeView: View {
    let title: String
    let steps: [(title: String, details: String)]
    let canLog: Bool                     // есть ли калории, чтобы записать в дневник
    let onAte: (Int) -> Void             // сколько порций съели

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var finished = false
    @State private var eatenServings = 1

    var body: some View {
        if finished {
            doneView
        } else {
            stepsView
        }
    }

    // Последний экран: приятного аппетита + запись в дневник
    var doneView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.green)

            Text("Enjoy your meal!")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Theme.dark)

            Text("How many servings of \(title) did you eat? We'll add them to today's diary.")
                .font(.title3)
                .foregroundStyle(.gray)

            ValueStepper(label: "Servings", value: $eatenServings, range: 1...10, unit: "")
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

            Spacer()

            HStack(spacing: 12) {
                SecondaryButton(title: "Skip") { dismiss() }
                PrimaryButton(title: "Add to diary") {
                    onAte(eatenServings)
                    dismiss()
                }
            }
        }
        .padding(20)
        .background(Theme.background)
    }

    var stepsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("STEP \(index + 1) OF \(steps.count)")
                    .font(.subheadline.bold())
                    .kerning(1)
                    .foregroundStyle(Theme.green)
                Spacer()
                Button("Close") { dismiss() }
                    .bold()
                    .foregroundStyle(Theme.green)
                    .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule().fill(i <= index ? Theme.green : Theme.border)
                }
            }
            .frame(height: 4)

            Text(title)
                .foregroundStyle(.gray)

            Spacer()

            if !steps.isEmpty {
                Text(steps[index].title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.dark)
                Text(steps[index].details)
                    .font(.title3)
                    .foregroundStyle(Theme.dark)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    index -= 1
                } label: {
                    Text("Back")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.dark)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 28)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.4 : 1)

                Button {
                    if index < steps.count - 1 {
                        index += 1
                    } else if canLog {
                        withAnimation { finished = true }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(index < steps.count - 1 ? "Next step" : "Done!")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Theme.background)
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            pick: RecipePick(title: "Chickpea tahini bowl", time: "25 min", colorIndex: 0,
                             equipmentUsed: ["oven", "frying pan"],
                             mainIngredients: ["chickpeas", "tahini", "sweet potato"]),
            dietTags: ["Vegan"],
            restrictionTags: ["Lactose-free"],
            equipment: ["Oven", "Frying pan", "Rice Cooker", "Knife & board"]
        )
    }
    .environment(HealthStore())
}

// MARK: - Калории и БЖУ (пересчитываются под число порций)

private struct NutritionSection: View {
    let nutrition: Nutrition.PartiallyGenerated?
    let servings: Int

    // ИИ считает на одну порцию — умножаем на выбранное число порций
    func total(_ perServing: Int?) -> Int? {
        perServing.map { $0 * servings }
    }

    var body: some View {
        if let n = nutrition {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NUTRITION")
                        .font(.caption.bold())
                        .kerning(1)
                        .foregroundStyle(Theme.green)
                    Spacer()
                    Text("for \(servings) \(servings == 1 ? "serving" : "servings") · AI estimate")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(total(n.calories).map { "\($0)" } ?? "…")
                                .font(.system(size: 40, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.dark)
                                .contentTransition(.numericText())
                            Text("kcal")
                                .font(.title3)
                                .foregroundStyle(.gray)
                        }

                        if let weight = n.servingWeight {
                            Text("Total \(weight * servings) g · 1 serving ≈ \(weight) g\(n.calories.map { ", \($0) kcal" } ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }

                    macroBar(n)

                    HStack(spacing: 8) {
                        tile("Protein", total(n.protein), Theme.green)
                        tile("Fat", total(n.fat), Theme.cardColors[0])
                        tile("Carbs", total(n.carbs), Theme.cardColors[2])
                        tile("Fiber", total(n.fiber), Theme.cardColors[1])
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: servings)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    // Полоска: какая доля калорий приходится на белки, жиры и углеводы
    func macroBar(_ n: Nutrition.PartiallyGenerated) -> some View {
        let protein = Double(n.protein ?? 0) * 4
        let fat = Double(n.fat ?? 0) * 9
        let carbs = Double(n.carbs ?? 0) * 4
        let total = protein + fat + carbs

        return GeometryReader { geo in
            if total > 0 {
                HStack(spacing: 2) {
                    Rectangle().fill(Theme.green)
                        .frame(width: geo.size.width * protein / total)
                    Rectangle().fill(Theme.cardColors[0])
                        .frame(width: geo.size.width * fat / total)
                    Rectangle().fill(Theme.cardColors[2])
                }
            } else {
                Rectangle().fill(Theme.beige)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    func tile(_ label: String, _ grams: Int?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Text(grams.map { "\($0) g" } ?? "…")
                .font(.headline)
                .foregroundStyle(Theme.dark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
    }
}
