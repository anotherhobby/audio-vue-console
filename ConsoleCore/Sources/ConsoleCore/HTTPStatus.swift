/// The HTTP statuses the host's contract gives, by the names the client's calls map them with.
enum HTTPStatus {
    static let ok = 200
    static let noContent = 204
    static let unauthorized = 401
    static let forbidden = 403
    static let notFound = 404
    static let conflict = 409
    static let tooManyRequests = 429
    static let serviceUnavailable = 503
}
