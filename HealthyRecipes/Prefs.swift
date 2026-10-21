import Foundation

// Сохранённый выбор пользователя: хранится на устройстве и не пропадает после перезапуска
enum Prefs {
    static let setupDoneKey = "setupDone"

    static var diet: Set<String> {
        get { load("diet") }
        set { save(newValue, "diet") }
    }

    static var restrictions: Set<String> {
        get { load("restrictions") }
        set { save(newValue, "restrictions") }
    }

    static var appliances: Set<String> {
        get { load("appliances", default: ["Stovetop", "Oven"]) }
        set { save(newValue, "appliances") }
    }

    static var tools: Set<String> {
        get { load("tools", default: ["Frying pan", "Saucepan", "Knife & board"]) }
        set { save(newValue, "tools") }
    }

    private static func load(_ key: String, default defaultValue: Set<String> = []) -> Set<String> {
        guard let array = UserDefaults.standard.stringArray(forKey: key) else { return defaultValue }
        return Set(array)
    }

    private static func save(_ value: Set<String>, _ key: String) {
        UserDefaults.standard.set(value.sorted(), forKey: key)
    }
}

let mealOptions = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]

// Какой приём пищи сейчас по времени суток
func mealForNow() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<11:  return "Breakfast"
    case 11..<16: return "Lunch"
    case 16..<22: return "Dinner"
    default:      return "Snack"
    }
}
