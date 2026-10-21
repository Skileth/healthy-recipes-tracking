import SwiftUI


@main
struct MyApp: App {
    @AppStorage(Prefs.setupDoneKey) private var setupDone = false
    @State private var health = HealthStore()
    @State private var stepCounter = StepCounter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if setupDone {
                    // Настройка уже пройдена — сразу рецепты
                    NavigationStack {
                        RecipesView()
                    }
                } else {
                    // Первый запуск — два шага настройки
                    ContentView {
                        setupDone = true
                    }
                }
            }
            .environment(health)
            .environment(stepCounter)
            // Открыли приложение — обновляем шаги
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    stepCounter.start()
                }
            }
        }
    }
}
