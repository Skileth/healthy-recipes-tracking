import SwiftUI

// Дневник питания: неделя, любой день, что съедено, вода и шаги
struct DiaryView: View {
    @Environment(HealthStore.self) private var health
    @Environment(StepCounter.self) private var stepCounter
    @Environment(\.dismiss) private var dismiss

    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var weekOffset = 0          // 0 — эта неделя, -1 — прошлая и т.д.
    @State private var showAddFood = false
    @State private var pastSteps: Int?

    private var calendar: Calendar { .current }
    private var isToday: Bool { calendar.isDateInToday(selected) }

    // 7 дней выбранной недели
    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: start) ?? start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        let targets = health.targets
        let log = health.day(selected)
        let totals = log.totals

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                weekCard(targets: targets)

                // ---------- Итог дня ----------
                VStack(alignment: .leading, spacing: 12) {
                    Text(dayTitle)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.dark)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(totals.calories)")
                                .font(.system(size: 40, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.dark)
                                .contentTransition(.numericText())
                            Text("/ \(targets.calories) kcal")
                                .font(.title3)
                                .foregroundStyle(.gray)
                        }
                        GoalBar(label: "Protein", value: totals.protein, goal: targets.protein, unit: "g", color: Theme.green)
                        GoalBar(label: "Fat", value: totals.fat, goal: targets.fat, unit: "g", color: Theme.cardColors[0])
                        GoalBar(label: "Carbs", value: totals.carbs, goal: targets.carbs, unit: "g", color: Theme.cardColors[2])
                        GoalBar(label: "Fiber", value: totals.fiber, goal: targets.fiber, unit: "g", color: Theme.cardColors[1])
                    }
                    .card()
                }

                // ---------- Что съедено ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "MEALS")

                    VStack(spacing: 0) {
                        if log.entries.isEmpty {
                            Text("Nothing logged for this day yet.")
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        ForEach(log.entries) { entry in
                            entryRow(entry)
                            if entry.id != log.entries.last?.id {
                                Divider()
                            }
                        }
                    }
                    .card()

                    PrimaryButton(title: "+ Add food") { showAddFood = true }
                }

                // ---------- Вода ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "WATER")
                    VStack(alignment: .leading, spacing: 16) {
                        GoalBar(label: "\(liters(totals.waterMl)) / \(liters(targets.waterMl)) L",
                                value: totals.waterMl / 250, goal: targets.waterMl / 250,
                                unit: "glasses", color: Theme.water)
                        HStack(spacing: 12) {
                            SecondaryButton(title: "−") { health.addWater(-250, on: selected) }
                            PrimaryButton(title: "+ Glass of water") { health.addWater(250, on: selected) }
                        }
                    }
                    .card()
                }

                // ---------- Шаги ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "STEPS")
                    VStack(alignment: .leading, spacing: 8) {
                        if let steps = isToday ? (stepCounter.isAvailable ? stepCounter.steps : nil) : pastSteps {
                            GoalBar(label: steps.formatted(), value: steps, goal: health.stepGoal, unit: "steps", color: Theme.green)
                        } else {
                            Text(stepCounter.isAvailable
                                 ? "No step data for this day. iPhone keeps steps for the last 7 days."
                                 : "Steps are counted by the iPhone's motion sensor. They aren't available on this device.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                    .card()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showAddFood) {
            AddFoodView(date: selected)
        }
        .task(id: selected) {
            pastSteps = isToday ? nil : await stepCounter.steps(on: selected)
        }
    }

    // MARK: - Части экрана

    var header: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            Text("Food diary")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.dark)
        }
    }

    var dayTitle: String {
        if isToday { return "Today" }
        if calendar.isDateInYesterday(selected) { return "Yesterday" }
        return selected.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    // Неделя: столбики калорий по дням, нажать на день — открыть его
    func weekCard(targets: DailyTargets) -> some View {
        let days = weekDays
        let today = calendar.startOfDay(for: .now)
        let pastDays = days.filter { $0 <= today }
        let logged = pastDays.map { health.day($0).totals.calories }.filter { $0 > 0 }
        let average = logged.isEmpty ? 0 : logged.reduce(0, +) / logged.count
        let onTarget = logged.filter {
            Double($0) >= Double(targets.calories) * 0.9 && Double($0) <= Double(targets.calories) * 1.1
        }.count

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    weekOffset -= 1
                    selected = weekDays.last ?? selected
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
                Text(weekRange(days))
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.dark)
                Spacer()

                Button {
                    weekOffset += 1
                    selected = min(weekDays.first ?? selected, today)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(weekOffset >= 0)
                .opacity(weekOffset >= 0 ? 0.3 : 1)
            }
            .font(.headline)
            .foregroundStyle(Theme.green)

            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayColumn(day, target: targets.calories, isFuture: day > today)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(logged.isEmpty
                 ? "No meals logged this week yet."
                 : "Average \(average) kcal a day · \(onTarget) of \(logged.count) days on target")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .card()
    }

    func dayColumn(_ day: Date, target: Int, isFuture: Bool) -> some View {
        let calories = health.day(day).totals.calories
        let ratio = target > 0 ? Double(calories) / Double(target) : 0
        let isSelected = calendar.isDate(day, inSameDayAs: selected)

        return Button {
            selected = day
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    Capsule().fill(Theme.beige)
                    Capsule()
                        .fill(ratio > 1.1 ? Theme.cardColors[2] : Theme.green)
                        .frame(height: 80 * min(1, ratio))
                }
                .frame(width: 22, height: 80)

                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? .white : Theme.dark)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Theme.green : .clear, in: Circle())
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.35 : 1)
    }

    func entryRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.dark)
                Text("P \(entry.protein) · F \(entry.fat) · C \(entry.carbs) · Fiber \(entry.fiber) g")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
            Text("\(entry.calories) kcal")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.dark)
            Button {
                withAnimation { health.remove(entry, on: selected) }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    func weekRange(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        if weekOffset == 0 { return "This week" }
        if weekOffset == -1 { return "Last week" }
        return "\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
    }

    func liters(_ ml: Int) -> String {
        (Double(ml) / 1000).formatted(.number.precision(.fractionLength(0...2)))
    }
}

#Preview {
    NavigationStack {
        DiaryView()
    }
    .environment(HealthStore())
    .environment(StepCounter())
}
