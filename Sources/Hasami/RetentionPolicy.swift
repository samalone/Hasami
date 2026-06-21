/// How the retention curve's half-life is determined.
public enum RetentionPolicy: Equatable {
    /// An absolute half-life in seconds: retention density halves every `seconds`
    /// of age, regardless of the total history span.
    case absoluteHalfLife(seconds: Double)
    /// A half-life expressed as a fraction of the history span (`span / value`),
    /// giving a scale-free retained shape.
    case halfLivesAcrossSpan(Double)
}

/// The reasons `RetentionPolicy.resolve(halfLife:halfLives:)` can reject its
/// command-line inputs. Each carries a ready-to-display `message`.
public enum RetentionPolicyError: Error, Equatable {
    case conflictingHalfLifeOptions
    case invalidDuration(String)
    case nonPositiveHalfLives

    public var message: String {
        switch self {
        case .conflictingHalfLifeOptions:
            return "Cannot specify both --half-life and --half-lives"
        case .invalidDuration(let value):
            return "Invalid --half-life value '\(value)'. Use e.g. 30d, 12h, 90m, 2w, or a number of seconds."
        case .nonPositiveHalfLives:
            return "--half-lives must be positive and finite"
        }
    }
}

extension RetentionPolicy {
    /// The default half-life when neither command-line option is supplied:
    /// `span / 4`, a scale-free relative half-life.
    public static let defaultHalfLivesAcrossSpan = 4.0

    /// Resolves the two mutually-exclusive command-line half-life options into a
    /// single `RetentionPolicy`, shared by both the `sukashi` and `sukashi-plan`
    /// CLIs so they stay in sync.
    ///
    /// - Parameters:
    ///   - halfLife: The raw `--half-life` duration string, if given.
    ///   - halfLives: The raw `--half-lives` value, if given.
    /// - Returns: The resolved policy.
    /// - Throws: `RetentionPolicyError` if both options are given, the duration
    ///   string is invalid, or `--half-lives` is not positive.
    public static func resolve(halfLife: String?, halfLives: Double?) throws -> RetentionPolicy {
        if halfLife != nil && halfLives != nil {
            throw RetentionPolicyError.conflictingHalfLifeOptions
        }
        if let halfLife {
            guard let seconds = DurationParser.seconds(from: halfLife) else {
                throw RetentionPolicyError.invalidDuration(halfLife)
            }
            return .absoluteHalfLife(seconds: seconds)
        }
        let k = halfLives ?? defaultHalfLivesAcrossSpan
        guard k > 0, k.isFinite else { throw RetentionPolicyError.nonPositiveHalfLives }
        return .halfLivesAcrossSpan(k)
    }
}
