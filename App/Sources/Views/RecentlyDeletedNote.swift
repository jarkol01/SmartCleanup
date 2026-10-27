import SwiftUI

extension Text {
    /// Shared wording wherever something gets deleted, so every screen explains it the same way.
    static var recentlyDeletedNote: Text {
        Text("Usunięte pliki trafiają do „Ostatnio usunięte”. Miejsce zwolni się dopiero, gdy usuniesz je stamtąd lub po 30 dniach.")
    }
}
