import SwiftUI
import FoundationModels

// MARK: - Шапка шага: "STEP 1 OF 3", полоска, заголовок

struct StepHeader: View {
    let step: Int
    var total = 3
    let title: String
    var subtitle: String? = nil
    var trailingLabel: String? = nil      // текстовая кнопка справа, например "Edit setup"
    var trailingAction: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("STEP \(step) OF \(total)")
                    .font(.subheadline.bold())
                    .kerning(1)
                    .foregroundStyle(Theme.green.opacity(0.8))
                Spacer()
                if let trailingLabel {
                    Button(trailingLabel, action: trailingAction)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.green)
                        .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.green : Theme.border)
                }
            }
            .frame(height: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.dark)
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

// MARK: - Зелёная подпись раздела: "1. HOW DO YOU EAT?"

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .kerning(1)
            .foregroundStyle(Theme.green)
    }
}

// MARK: - Кнопка-выбор (нажал — зелёная, ещё раз — белая)

struct ChoiceChip: View {
    let title: String
    @Binding var selection: Set<String>

    var body: some View {
        Chip(title: title, isOn: selection.contains(title)) {
            if selection.contains(title) {
                selection.remove(title)
            } else {
                selection.insert(title)
            }
        }
    }
}

// Та же кнопка, но что делать при нажатии решаешь сам (например, выбрать только один вариант)
struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? .white : Theme.dark)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isOn ? Theme.green : Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isOn ? Theme.green : Theme.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

// MARK: - Большая зелёная кнопка

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.green, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Белая кнопка с рамкой (например "Back")

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Theme.dark)
                .padding(.vertical, 16)
                .padding(.horizontal, 28)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// Понятный текст, если ИИ недоступен
func aiUnavailableMessage(_ availability: SystemLanguageModel.Availability) -> String {
    switch availability {
    case .available:
        return ""
    case .unavailable(let reason):
        switch reason {
        case .modelNotReady:
            return "The AI chef is still getting ready (downloading). Keep your device on Wi‑Fi and charging, then try again in a few minutes."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to get recipes."
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so the AI chef can't work here."
        @unknown default:
            return "The AI chef isn't available right now. Please try again later."
        }
    }
}

// Общие правила для ИИ-шефа: чтобы рецепты были как у нормального человека дома
let chefRules = """
Rules for every recipe:
- The kitchen equipment list is what the user HAS, not what they must use. Use as FEW tools as possible: most home dishes need only one or two.
- Never cook the same food in two appliances that do the same job (for example toaster then grill, oven then air fryer, frying pan then grill).
- Cook each ingredient only once, unless a well-known recipe really needs two stages.
- Only suggest real, well-known dishes that people actually cook at home. No strange combinations.
- Cooking times, temperatures and amounts must be realistic.
Examples of good thinking:
- Avocado toast: toast the bread in the toaster, mash the avocado with a fork, put it on top. No grill, no pan.
- Pasta with tomato sauce: boil the pasta in a saucepan, cook the sauce in a frying pan. No oven.
"""

// MARK: - Белая карточка

extension View {
    func card() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Полоска прогресса: "Protein  42 / 104 g"

struct GoalBar: View {
    let label: String
    let value: Int
    let goal: Int
    let unit: String
    let color: Color

    var progress: Double {
        goal > 0 ? min(1, Double(value) / Double(goal)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.dark)
                Spacer()
                Text("\(value) / \(goal) \(unit)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.beige)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
            .animation(.easeInOut, value: progress)
        }
    }
}

// MARK: - Число с кнопками − / +: "Weight   − 65 kg +"

struct ValueStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.dark)
            Spacer()
            HStack(spacing: 14) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)

                Text("\(value) \(unit)")
                    .bold()
                    .monospacedDigit()
                    .frame(minWidth: 80)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.dark)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.background, in: Capsule())
        }
    }
}
