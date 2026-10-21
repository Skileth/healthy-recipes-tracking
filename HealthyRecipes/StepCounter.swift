import SwiftUI
import Observation
#if os(iOS)
import CoreMotion
#endif

// Шаги за сегодня с датчика движения iPhone
@Observable
final class StepCounter {
    private(set) var steps = 0
    private(set) var isAvailable = false

    #if os(iOS)
    @ObservationIgnored private let pedometer = CMPedometer()
    #endif

    init() {
        #if os(iOS)
        isAvailable = CMPedometer.isStepCountingAvailable()
        #endif
    }

    // Считаем с начала сегодняшнего дня и дальше обновляем на ходу
    func start() {
        #if os(iOS)
        guard isAvailable else { return }
        pedometer.stopUpdates()
        pedometer.startUpdates(from: Calendar.current.startOfDay(for: .now)) { @Sendable data, _ in
            let count = data?.numberOfSteps.intValue ?? 0
            Task { @MainActor in
                self.steps = count
            }
        }
        #endif
    }

    // Шаги за любой из последних 7 дней (дольше iPhone не хранит)
    func steps(on date: Date) async -> Int? {
        #if os(iOS)
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let end = min(nextDay, .now)
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { @Sendable data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        #else
        return nil
        #endif
    }
}
