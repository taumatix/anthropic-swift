import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

extension SkillFile {

    /// Reads a skill's directory into the file set ``SkillsService/create(files:displayName:)``
    /// uploads.
    ///
    /// Each file's path is prefixed with the directory's own name, as the API expects:
    /// `my-skill/SKILL.md`, `my-skill/scripts/run.py`. Its MIME type comes from its extension.
    ///
    /// ```swift
    /// let skill = try await client.skills.create(files: try SkillFile.directory(at: skillURL))
    /// ```
    ///
    /// Hidden files and directories (`.DS_Store`, `.git`) are left out, and so are symbolic
    /// links, which could point anywhere on the machine. Files are in path order.
    ///
    /// - Throws: ``AnthropicError/encodingError(_:)`` if `url` is not a directory or has no
    ///   `SKILL.md` at its root. That is a stricter check than `create` makes, since `create` sees
    ///   only paths. Throws the underlying error if a file cannot be read.
    public static func directory(at url: URL) throws -> [SkillFile] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw invalidDirectory(url, "\(url.path) is not a directory.")
        }

        let name = url.lastPathComponent
        let base = url.resolvingSymlinksInPath().standardizedFileURL.path
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let walker = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            throw invalidDirectory(url, "\(url.path) could not be read.")
        }

        var files: [SkillFile] = []
        for case let fileURL as URL in walker {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true || values.isRegularFile != true {
                continue
            }
            let full = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            guard full.hasPrefix(base + "/") else { continue }
            let relative = String(full.dropFirst(base.count + 1))
            files.append(SkillFile(
                path: "\(name)/\(relative)",
                content: try Data(contentsOf: fileURL),
                mimeType: mimeType(forExtension: fileURL.pathExtension)
            ))
        }
        files.sort { $0.path < $1.path }

        guard files.contains(where: { $0.path == "\(name)/SKILL.md" }) else {
            throw invalidDirectory(url, "A skill directory must have a SKILL.md at its root; \(url.path) does not.")
        }
        return files
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "md", "markdown": return "text/markdown"
        case "": return "application/octet-stream"
        default:
            #if canImport(UniformTypeIdentifiers)
            if let type = UTType(filenameExtension: ext), let mime = type.preferredMIMEType {
                return mime
            }
            #endif
            return "application/octet-stream"
        }
    }

    private static func invalidDirectory(_ url: URL, _ reason: String) -> AnthropicError {
        .encodingError(EncodingError.invalidValue(url, .init(codingPath: [], debugDescription: reason)))
    }
}
