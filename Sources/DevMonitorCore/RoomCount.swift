import Foundation

/// The count the menu bar shows: how many accounts still have room, out of how many are followed.
public enum RoomCount {
    /// From this share used, a limit counts as full.
    public static let fullAt: Double = 95

    /// Returns how many of these accounts have every limit under 95 % by their last usage read, and how many there
    /// are. An account never read, or read without any limit, has no room to count.
    /// @example RoomCount.of([usage(15, 17), usage(97), nil]) // (withRoom: 1, total: 3)
    public static func of(_ usages: [AccountUsage?]) -> (withRoom: Int, total: Int) {
        let withRoom = usages.filter { usage in usage?.fullest.map { $0.percentUsed < fullAt } ?? false }.count
        return (withRoom, usages.count)
    }
}
