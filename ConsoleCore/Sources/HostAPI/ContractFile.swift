package import Foundation

/// The saved contract as bundled with this target, which `ConsoleCore` reads for the API version it
/// supports and the operations that take no token (`host-client`).
package enum ContractFile {
    /// The bundled `openapi.json`, or nil where the bundle lacks it, which only a broken build does.
    package static var url: URL? {
        Bundle.module.url(forResource: "openapi", withExtension: "json")
    }
}
