import SwiftUI

// Профиль: дневная норма и прогресс, вода, шаги, данные о себе и предпочтения
struct ProfileView: View {
    @Environment(HealthStore.self) private var health
    @Environment(StepCounter.self) private var stepCounter
    @Environment(\.dismiss) private var dismiss

    @State private var showSetup = false
    @State private var diet = Prefs.diet
    @State private var restrictions = Prefs.restrictions
    @State private var kitchen = Prefs.appliances.union(Prefs.tools)

    var body: some View {
        @Bindable var health = health
        let targets = health.targets

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                // ---------- Норма на день ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "DAILY TARGETS")
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(targets.calories)")
                                .font(.system(size: 40, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.dark)
                                .contentTransition(.numericText())
                            Text("kcal a day")
                                .font(.title3)
                                .foregroundStyle(.gray)
                        }
                        HStack(spacing: 8) {
                            targetTile("Protein", "\(targets.protein) g", Theme.green)
                            targetTile("Fat", "\(targets.fat) g", Theme.cardColors[0])
                            targetTile("Carbs", "\(targets.carbs) g", Theme.cardColors[2])
                        }
                        HStack(spacing: 8) {
                            targetTile("Fiber", "\(targets.fiber) g", Theme.cardColors[1])
                            targetTile("Water", "\(liters(targets.waterMl)) L", Theme.water)
                            targetTile("Steps", health.stepGoal.formatted(), Theme.dark)
                        }
                    }
                    .card()

                    NavigationLink {
                        DiaryView()
                    } label: {
                        HStack {
                            Image(systemName: "book.closed.fill")
                            Text("Open food diary")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.green)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }

                // ---------- Шаги ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "STEPS")
                    VStack(alignment: .leading, spacing: 16) {
                        if stepCounter.isAvailable {
                            Text(stepCounter.steps.formatted())
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.dark)
                                .contentTransition(.numericText())
                            GoalBar(label: "Today", value: stepCounter.steps, goal: health.stepGoal, unit: "steps", color: Theme.green)
                        } else {
                            Text("Steps are counted by the iPhone's motion sensor. They aren't available on this device.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        ValueStepper(label: "Daily goal", value: $health.stepGoal, range: 1000...30000, step: 1000, unit: "")
                    }
                    .card()
                }

                // ---------- Цель ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "YOUR GOAL")
                    FlowLayout(spacing: 8) {
                        ForEach(WeightGoal.allCases, id: \.self) { option in
                            Chip(title: option.rawValue, isOn: health.goal == option) { health.goal = option }
                        }
                    }
                }

                // ---------- О себе ----------
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "ABOUT YOU")
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            ForEach(Sex.allCases, id: \.self) { option in
                                Chip(title: option.rawValue, isOn: health.sex == option) { health.sex = option }
                            }
                        }
                        ValueStepper(label: "Age", value: $health.age, range: 12...100, unit: "y")
                        ValueStepper(label: "Height", value: $health.height, range: 120...220, unit: "cm")
                        ValueStepper(label: "Weight", value: $health.weight, range: 30...250, unit: "kg")

                        Text("Activity")
                            .foregroundStyle(Theme.dark)
                            .padding(.top, 4)
                        FlowLayout(spacing: 8) {
                            ForEach(Activity.allCases, id: \.self) { option in
                                Chip(title: option.rawValue, isOn: health.activity == option) { health.activity = option }
                            }
                        }
                        Text(health.activity.hint)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .card()

                    Text("Your daily targets are calculated from this. They're an estimate, not medical advice.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                // ---------- Предпочтения ----------
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(text: "FOOD PREFERENCES")
                        Spacer()
                        Button("Edit") { showSetup = true }
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.green)
                            .buttonStyle(.plain)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        tagGroup("Diet", diet.isEmpty ? ["No preference"] : diet.sorted())
                        tagGroup("Restrictions", restrictions.isEmpty ? ["None"] : restrictions.sorted())
                        tagGroup("Kitchen", kitchen.sorted())
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
        .sheet(isPresented: $showSetup, onDismiss: reloadPrefs) {
            ContentView(isEditing: true) {
                showSetup = false
            }
        }
    }

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

            Text("Your profile")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.dark)
        }
    }

    func targetTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.dark)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
    }

    func tagGroup(_ title: String, _ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.dark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.beige, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    func liters(_ ml: Int) -> String {
        (Double(ml) / 1000).formatted(.number.precision(.fractionLength(0...2)))
    }

    func reloadPrefs() {
        diet = Prefs.diet
        restrictions = Prefs.restrictions
        kitchen = Prefs.appliances.union(Prefs.tools)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(HealthStore())
    .environment(StepCounter())
}
