extension SpectrePro {
    /// Possible errors from internal SpectrePro calls.
    enum Error: Swift.Error, CustomLocalizedStringResourceConvertible {
        case apiFailed

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .apiFailed: return "libspectrepro API call failed"
            }
        }
    }
}
