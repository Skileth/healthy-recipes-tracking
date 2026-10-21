import SwiftUI
import Observation

// MARK: - Данные о человеке

enum Sex: String, CaseIterable {
    case female = "Female"
    case male = "Male"
}

enum Activity: String, CaseIterable {
    case low = "Low"
    case light = "Light"
    case moderate = "Moderate"
    case high = "High"

    var factor: Double {
        switch self {
        case .low: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .high: 1.725
        }
    }

    var hint: String {
        switch self {
        case .low: "Mostly sitting, little walking"
        case .light: "Walks, 1–3 workouts a week"
        case .moderate: "3–5 workouts a week"
        case .high: "Sport almost every day"
        }
    }
}

enum WeightGoal: String, CaseIterable {
    case lose = "Lose weight"
    case maintain = "Keep weight"
    case gain = "Gain weight"

    var calorieShift: Double {
        switch self {
        case .lose: -400
        case .maintain: 0
        case .gain: 300
        }
    }
}

// Сколько нужно в день
struct DailyTargets {
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let fiber: Int
    let waterMl: Int
}

// Итог за день: сколько съедено и выпито
struct Intake: Codable {
    var calories = 0
    var protein = 0
    var fat = 0
    var carbs = 0
    var fiber = 0
    var waterMl = 0
}

// Одна запись в дневнике: блюдо или продукт
struct FoodEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var calories: Int
    var protein: Int
    var fat: Int
    var carbs: Int
    var fiber: Int
    var date = Date.now
}

// Дневник за один день
struct DayLog: Codable {
    var entries: [FoodEntry] = []
    var waterMl = 0

    var totals: Intake {
        entries.reduce(into: Intake(waterMl: waterMl)) { total, entry in
            total.calories += entry.calories
            total.protein += entry.protein
            total.fat += entry.fat
            total.carbs += entry.carbs
            total.fiber += entry.fiber
        }
    }
}

// MARK: - Профиль и дневник за сегодня (хранится на устройстве)

@Observable
final class HealthStore {
    var sex: Sex { didSet { defaults.set(sex.rawValue, forKey: "profile.sex") } }
    var age: Int { didSet { defaults.set(age, forKey: "profile.age") } }
    var height: Int { didSet { defaults.set(height, forKey: "profile.height") } }     // см
    var weight: Int { didSet { defaults.set(weight, forKey: "profile.weight") } }     // кг
    var activity: Activity { didSet { defaults.set(activity.rawValue, forKey: "profile.activity") } }
    var goal: WeightGoal { didSet { defaults.set(goal.rawValue, forKey: "profile.goal") } }
    var stepGoal: Int { didSet { defaults.set(stepGoal, forKey: "profile.stepGoal") } }

    // Все дни дневника: ключ "day.2026-10-20"
    private(set) var days: [String: DayLog] = [:]

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        sex = Sex(rawValue: d.string(forKey: "profile.sex") ?? "") ?? .female
        age = d.object(forKey: "profile.age") as? Int ?? 30
        height = d.object(forKey: "profile.height") as? Int ?? 168
        weight = d.object(forKey: "profile.weight") as? Int ?? 65
        activity = Activity(rawValue: d.string(forKey: "profile.activity") ?? "") ?? .light
        goal = WeightGoal(rawValue: d.string(forKey: "profile.goal") ?? "") ?? .maintain
        stepGoal = d.object(forKey: "profile.stepGoal") as? Int ?? 10_000
        loadDays()
    }

    // Норма на день по формуле Миффлина — Сан Жеора
    var targets: DailyTargets {
        let w = Double(weight), h = Double(height), a = Double(age)
        let bmr = 10 * w + 6.25 * h - 5 * a + (sex == .male ? 5 : -161)
        let calories = max(1200, bmr * activity.factor + goal.calorieShift)
        let protein = w * (goal == .maintain ? 1.6 : 1.8)
        let fat = calories * 0.3 / 9
        let carbs = max(0, (calories - protein * 4 - fat * 9) / 4)
        let fiber = calories / 1000 * 14
        let water = (w * 33 / 250).rounded() * 250

        return DailyTargets(
            calories: Int(calories),
            protein: Int(protein),
            fat: Int(fat),
            carbs: Int(carbs),
            fiber: Int(fiber),
            waterMl: Int(water)
        )
    }

    // MARK: Дневник

    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "day.%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func day(_ date: Date) -> DayLog {
        days[Self.key(date)] ?? DayLog()
    }

    var today: Intake { day(.now).totals }

    func add(_ entry: FoodEntry, on date: Date) {
        var log = day(date)
        log.entries.append(entry)
        save(log, for: date)
    }

    func remove(_ entry: FoodEntry, on date: Date) {
        var log = day(date)
        log.entries.removeAll { $0.id == entry.id }
        save(log, for: date)
    }

    func addWater(_ ml: Int, on date: Date = .now) {
        var log = day(date)
        log.waterMl = max(0, log.waterMl + ml)
        save(log, for: date)
    }

    private func save(_ log: DayLog, for date: Date) {
        let key = Self.key(date)
        days[key] = log
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadDays() {
        for (key, value) in defaults.dictionaryRepresentation() {
            guard let data = value as? Data else { continue }

            if key.hasPrefix("day."), let log = try? JSONDecoder().decode(DayLog.self, from: data) {
                days[key] = log
            }

            // Старый формат (только суммы за день) переносим в новый
            if key.hasPrefix("intake."), let old = try? JSONDecoder().decode(Intake.self, from: data) {
                var log = DayLog(waterMl: old.waterMl)
                if old.calories > 0 {
                    log.entries.append(FoodEntry(name: "Logged earlier", calories: old.calories, protein: old.protein,
                                                 fat: old.fat, carbs: old.carbs, fiber: old.fiber))
                }
                let newKey = "day." + key.dropFirst("intake.".count)
                days[newKey] = log
                if let encoded = try? JSONEncoder().encode(log) {
                    defaults.set(encoded, forKey: newKey)
                }
                defaults.removeObject(forKey: key)
            }
        }
    }
}
