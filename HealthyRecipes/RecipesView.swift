import SwiftUI
import FoundationModels

// MARK: - Цвета экрана

enum Theme {
    static let background = Color(red: 0.965, green: 0.953, blue: 0.925)
    static let green      = Color(red: 0.19, green: 0.42, blue: 0.25)
    static let lightGreen = Color(red: 0.88, green: 0.93, blue: 0.86)
    static let beige      = Color(red: 0.94, green: 0.92, blue: 0.87)
    static let dark       = Color(red: 0.13, green: 0.17, blue: 0.13)
    static let border     = Color(red: 0.86, green: 0.84, blue: 0.79)
    static let chefLabel  = Color(red: 0.70, green: 0.85, blue: 0.62)
    static let water      = Color(red: 0.45, green: 0.65, blue: 0.85)
    static let cardColors: [Color] = [
        Color(red: 0.91, green: 0.72, blue: 0.45),
        Color(red: 0.72, green: 0.80, blue: 0.64),
        Color(red: 0.85, green: 0.63, blue: 0.49)
    ]
}

// MARK: - Что ИИ должен вернуть (короткая версия рецепта)

@Generable
struct Recipe {
    @Guide(description: "Short appetizing recipe name, 2-4 words")
    let title: String

    @Guide(description: "Total cooking time, for example '25 min'")
    let time: String

    @Guide(description: "Estimated calories per serving, kcal", .range(30...2000))
    let calories: Int

    @Guide(description: "Only the equipment this recipe really uses, usually just one or two, from the available list, short lowercase words like 'stove' or 'oven'", .count(1...2))
    let equipmentUsed: [String]

    @Guide(description: "One short appetizing sentence describing the dish")
    let summary: String

    @Guide(description: "Main ingredient names without amounts", .count(3...5))
    let mainIngredients: [String]
}

@Generable
struct RecipeList {
    @Guide(description: "One or two friendly sentences from the chef about these recipes, ending with a short question offering to adjust them")
    let intro: String

    @Guide(description: "Different recipes", .count(3))
    let recipes: [Recipe]
}

// MARK: - Экран

struct RecipesView: View {
    // Сохранённый выбор (из Prefs.swift)
    @State private var diet = Prefs.diet
    @State private var restrictions = Prefs.restrictions
    @State private var equipment = Prefs.appliances.union(Prefs.tools)

    // Приём пищи: по умолчанию по времени суток
    @State private var meal = mealForNow()
    @State private var mealIsManual = false      // пользователь сам переключил

    @State private var showProfile = false
    @Environment(HealthStore.self) private var health
    @Environment(StepCounter.self) private var stepCounter
    @State private var loadTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: LanguageModelSession?
    @State private var intro: String?
    @State private var recipes: [Recipe.PartiallyGenerated] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var question = ""
    @State private var picked: RecipePick?      // какой рецепт открыть полностью
    @FocusState private var isTyping: Bool

    let quickAsks: [(label: String, prompt: String)] = [
        ("Faster", "Give me 3 faster recipes, under 20 minutes."),
        ("More protein", "Give me 3 recipes with more protein."),
        ("Use what I have", "Give me 3 recipes using only basic pantry ingredients most people already have at home.")
    ]

    var titleText: String { "\(meal) ideas for you" }
    var dietTags: [String] { diet.filter { $0 != "I eat everything" }.sorted() }
    var restrictionTags: [String] { restrictions.sorted() }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayStrip
                    tagsRow
                    chefCard

                    ForEach(recipes.indices, id: \.self) { i in
                        RecipeCard(
                            recipe: recipes[i],
                            color: Theme.cardColors[i % Theme.cardColors.count],
                            dietTags: dietTags,
                            restrictionTags: restrictionTags,
                            canOpen: !isLoading
                        ) {
                            open(recipes[i], index: i)
                        }
                    }

                    if !recipes.isEmpty && !isLoading {
                        quickButtons
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) { askBar }
        .navigationDestination(item: $picked) { pick in
            RecipeDetailView(
                pick: pick,
                dietTags: dietTags,
                restrictionTags: restrictionTags,
                equipment: equipment
            )
        }
        .navigationDestination(isPresented: $showProfile) {
            ProfileView()
        }
        .onAppear {
            if loadTask == nil {
                reload()
            } else if diet != Prefs.diet || restrictions != Prefs.restrictions
                        || equipment != Prefs.appliances.union(Prefs.tools) {
                // Вернулись из профиля, где поменяли предпочтения
                reloadSetup()
            }
        }
        // Вернулись в приложение позже — если время суток сменилось, показываем новый приём пищи
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !mealIsManual, meal != mealForNow() {
                meal = mealForNow()
                reload()
            }
        }
    }

    // MARK: - Части экрана

    var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                    .font(.subheadline.bold())
                    .kerning(1)
                    .foregroundStyle(Theme.green.opacity(0.8))
                Spacer()
                Button {
                    showProfile = true
                } label: {
                    Image(systemName: "person.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.green, in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(titleText)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.dark)

            // Переключатель приёма пищи
            FlowLayout(spacing: 8) {
                ForEach(mealOptions, id: \.self) { option in
                    Chip(title: option, isOn: option == meal) {
                        guard option != meal else { return }
                        meal = option
                        mealIsManual = true
                        reload()
                    }
                }
            }
        }
    }

    // Сегодня: калории, вода, шаги. Нажать — откроется дневник
    var todayStrip: some View {
        NavigationLink {
            DiaryView()
        } label: {
            HStack(spacing: 16) {
                stat("flame.fill", "\(health.today.calories) / \(health.targets.calories) kcal", Theme.cardColors[2])
                stat("drop.fill", "\(liters(health.today.waterMl)) / \(liters(health.targets.waterMl)) L", Theme.water)
                if stepCounter.isAvailable {
                    stat("figure.walk", stepCounter.steps.formatted(), Theme.green)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    func liters(_ ml: Int) -> String {
        (Double(ml) / 1000).formatted(.number.precision(.fractionLength(0...2)))
    }

    func stat(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .monospacedDigit()
                .foregroundStyle(Theme.dark)
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }

    var tagsRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(dietTags + restrictionTags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.green, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("\(equipment.count) tools")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.dark)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1.5))
        }
    }

    var chefCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI CHEF")
                .font(.caption.bold())
                .kerning(1)
                .foregroundStyle(Theme.chefLabel)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.white)
                Button("Try again") {
                    reload()
                }
                .font(.subheadline.bold())
                .foregroundStyle(Theme.chefLabel)
                .buttonStyle(.plain)
            } else if let intro {
                Text(intro)
                    .foregroundStyle(.white)
            } else {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Thinking about what you can cook…")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .font(.title3)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dark, in: RoundedRectangle(cornerRadius: 24))
    }

    var quickButtons: some View {
        FlowLayout(spacing: 8) {
            ForEach(quickAsks, id: \.label) { item in
                Button {
                    follow(item.prompt)
                } label: {
                    Text(item.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.dark)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    var askBar: some View {
        HStack {
            TextField("Ask the AI chef…", text: $question)
                .textFieldStyle(.plain)          // ← убирает серую полоску
                .foregroundStyle(Theme.dark)
                .focused($isTyping)
                .submitLabel(.send)
                .onSubmit { send() }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.green, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.leading, 20)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1.5))
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .background(Theme.background)
    }

    // MARK: - Действия

    func open(_ recipe: Recipe.PartiallyGenerated, index: Int) {
        guard let title = recipe.title else { return }
        picked = RecipePick(
            title: title,
            time: recipe.time ?? "",
            colorIndex: index,
            equipmentUsed: recipe.equipmentUsed ?? [],
            mainIngredients: recipe.mainIngredients ?? []
        )
    }

    func send() {
        let text = question.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        question = ""
        isTyping = false
        follow(text)
    }

    // Новый разговор с ИИ с нуля (при запуске, смене приёма пищи или настроек)
    func reload() {
        schedule {
            session = nil
            await start()
        }
    }

    // Продолжить разговор: "Faster", "More protein" или свой вопрос
    func follow(_ text: String) {
        schedule { await ask(text) }
    }

    // Отменяем то, что ИИ делал до этого, и запускаем новое
    private func schedule(_ work: @escaping () async -> Void) {
        let previous = loadTask
        previous?.cancel()
        loadTask = Task {
            await previous?.value
            await work()
        }
    }

    // Пользователь сохранил новые настройки
    func reloadSetup() {
        diet = Prefs.diet
        restrictions = Prefs.restrictions
        equipment = Prefs.appliances.union(Prefs.tools)
        reload()
    }

    func start() async {
        errorText = nil
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            errorText = aiUnavailableMessage(availability)
            return
        }

        session = LanguageModelSession(instructions: """
        You are a friendly AI chef inside a cooking app.
        The user's setup:
        Diet: \(dietTags.isEmpty ? "no preference" : dietTags.joined(separator: ", "))
        Restrictions: \(restrictionTags.isEmpty ? "none" : restrictionTags.joined(separator: ", "))
        Meal: \(meal)
        Kitchen equipment available: \(equipment.isEmpty ? "almost nothing" : equipment.joined(separator: ", "))
        Always strictly follow the diet and restrictions and use ONLY the listed equipment.
        When the user asks for changes, suggest 3 new recipes that follow their request.
        \(chefRules)
        """)

        await ask("Suggest 3 different \(meal.lowercased()) recipes for me for today.")
    }

    func ask(_ text: String) async {
        guard let session, !isLoading else { return }
        isLoading = true
        errorText = nil
        intro = nil
        recipes = []
        defer { isLoading = false }

        do {
            let stream = session.streamResponse(
                to: text,
                generating: RecipeList.self,
                options: GenerationOptions(temperature: 0.5)   // меньше фантазии — рецепты реалистичнее
            )
            for try await snapshot in stream {
                intro = snapshot.content.intro
                recipes = snapshot.content.recipes ?? []
            }
        } catch {
            if Task.isCancelled { return }      // мы сами отменили — это не ошибка
            print("AI error:", error)
            errorText = "Something went wrong. \(error.localizedDescription)"
        }
    }
}

// MARK: - Карточка рецепта

struct RecipeCard: View {
    let recipe: Recipe.PartiallyGenerated
    let color: Color
    let dietTags: [String]
    let restrictionTags: [String]
    let canOpen: Bool
    let onShowFull: () -> Void

    @State private var isOpen = false

    var subtitle: String {
        [recipe.time, recipe.calories.map { "\($0) kcal" }, recipe.equipmentUsed?.joined(separator: ", ")]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.title ?? "…")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.dark)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    FlowLayout(spacing: 6) {
                        ForEach(dietTags, id: \.self) { tag in
                            Text(tag)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.lightGreen, in: RoundedRectangle(cornerRadius: 10))
                        }
                        ForEach(restrictionTags, id: \.self) { tag in
                            Text(tag)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.dark.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.beige, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            // Короткая часть рецепта
            if isOpen {
                if let summary = recipe.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dark)
                }
                if let main = recipe.mainIngredients, !main.isEmpty {
                    Text("Main: \(main.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                Button {
                    onShowFull()
                } label: {
                    HStack(spacing: 6) {
                        Text("Show full recipe")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.green, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canOpen)
                .opacity(canOpen ? 1 : 0.5)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { isOpen.toggle() }
        }
    }
}

#Preview {
    NavigationStack {
        RecipesView()
    }
    .environment(HealthStore())
    .environment(StepCounter())
}
