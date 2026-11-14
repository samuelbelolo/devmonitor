/// How much a Mac leans on its swap, measured against the memory it has: macOS grows the swap as it fills, so its own
/// share used says nothing, and the free memory macOS reports stays high while the Mac crawls.
public enum SwapState: Sendable, Equatable {
    /// Up to a quarter of the installed memory.
    case fine
    /// Above a quarter of the installed memory.
    case high
    /// Above half of the installed memory: only a restart gives it back.
    case critical
}
