import Foundation

public struct LogRecord: Codable {
    public let id: String
    public let timestamp: String
    public let date: String
    public let entry: String
}

public struct HasLoggedResponse: Codable {
    public let has_logged: Bool
    public let date: String
    public let count: Int?
}

public struct ListResponse: Codable {
    public let entries: [LogRecord]
    public let count: Int
}

public enum ProcessRunnerError: LocalizedError {
    case pythonNotFound
    case scriptNotFound(String)
    case executionFailed(Int32, String)
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "python3 interpreter was not found on this system."
        case .scriptNotFound(let path):
            return "backend/logger.py was not found at path: \(path)"
        case .executionFailed(let code, let msg):
            return "Python command failed with exit code \(code): \(msg)"
        case .invalidOutput(let msg):
            return "Failed to parse backend output: \(msg)"
        }
    }
}

public final class ProcessRunner {
    public static let shared = ProcessRunner()

    private let fileManager = FileManager.default

    public init() {}

    /// Resolve the python3 executable path
    public func resolvePythonPath() -> String {
        if let envPython = ProcessInfo.processInfo.environment["LOGGER_PYTHON_PATH"],
           fileManager.isExecutableFile(atPath: envPython) {
            return envPython
        }

        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        for path in candidates {
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/usr/bin/env"
    }

    /// Resolve the backend/logger.py script path
    public func resolveScriptPath() -> String {
        if let envScript = ProcessInfo.processInfo.environment["LOGGER_BACKEND_SCRIPT"],
           fileManager.fileExists(atPath: envScript) {
            return envScript
        }

        // Try relative to the executable path (e.g. <repo>/bin/DailyLoggerUI -> <repo>/backend/logger.py)
        let executableCandidatePath: String? = {
            let path = Bundle.main.executablePath ?? CommandLine.arguments.first
            guard let rawPath = path else { return nil }
            return URL(fileURLWithPath: rawPath).resolvingSymlinksInPath().path
        }()

        if let execPath = executableCandidatePath {
            var execURL = URL(fileURLWithPath: execPath).deletingLastPathComponent()
            for _ in 0..<5 {
                let candidate = execURL.appendingPathComponent("backend/logger.py").path
                if fileManager.fileExists(atPath: candidate) {
                    return candidate
                }
                execURL.deleteLastPathComponent()
            }
        }

        // Try current working directory
        let cwd = fileManager.currentDirectoryPath
        let directCandidate = (cwd as NSString).appendingPathComponent("backend/logger.py")
        if fileManager.fileExists(atPath: directCandidate) {
            return directCandidate
        }

        // Search upward if running from within ui/ or deeper
        var currentURL = URL(fileURLWithPath: cwd)
        for _ in 0..<4 {
            let candidate = currentURL.appendingPathComponent("backend/logger.py").path
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
            currentURL.deleteLastPathComponent()
        }

        // Default fallback to directCandidate
        return directCandidate
    }

    /// Execute the Python CLI with the given arguments
    @discardableResult
    public func run(arguments: [String]) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let pythonPath = resolvePythonPath()
        let scriptPath = resolveScriptPath()

        guard fileManager.fileExists(atPath: scriptPath) else {
            throw ProcessRunnerError.scriptNotFound(scriptPath)
        }

        let process = Process()
        if pythonPath == "/usr/bin/env" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", scriptPath] + arguments
        } else {
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath] + arguments
        }

        var env = ProcessInfo.processInfo.environment
        if let logFilePath = env["DAILY_LOG_FILE"] {
            env["DAILY_LOG_FILE"] = logFilePath
        }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    /// Query whether a log entry has already been written for the current cycle
    public func hasLogged(date: String? = nil) throws -> Bool {
        var args = ["has-logged"]
        if let date = date {
            args += ["--date", date]
        }

        let result = try run(arguments: args)
        if result.exitCode == 0 {
            return true
        }

        // Also check stdout JSON
        if let data = result.stdout.data(using: .utf8),
           let response = try? JSONDecoder().decode(HasLoggedResponse.self, from: data) {
            return response.has_logged
        }
        return false
    }

    /// Save a new log entry
    public func saveLog(text: String, date: String? = nil) throws -> LogRecord {
        var args = ["log", "--text", text]
        if let date = date {
            args += ["--date", date]
        }

        let result = try run(arguments: args)
        guard result.exitCode == 0 else {
            throw ProcessRunnerError.executionFailed(result.exitCode, result.stderr)
        }

        struct LogResponse: Codable {
            let status: String
            let record: LogRecord
        }

        guard let data = result.stdout.data(using: .utf8),
              let response = try? JSONDecoder().decode(LogResponse.self, from: data) else {
            throw ProcessRunnerError.invalidOutput(result.stdout)
        }

        return response.record
    }

    /// Retrieve logged entries
    public func listLogs(limit: Int = 10) throws -> [LogRecord] {
        let args = ["list", "--limit", String(limit), "--reverse"]
        let result = try run(arguments: args)
        guard result.exitCode == 0 else {
            throw ProcessRunnerError.executionFailed(result.exitCode, result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8),
              let response = try? JSONDecoder().decode(ListResponse.self, from: data) else {
            throw ProcessRunnerError.invalidOutput(result.stdout)
        }

        return response.entries
    }
}
