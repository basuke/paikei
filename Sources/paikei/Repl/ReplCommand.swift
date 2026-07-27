import ArgumentParser
import Foundation
import PaikeiCore

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// 対話モード。引数なしで `paikei` を起動したときの既定動作。
struct ReplCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repl",
        abstract: "対話モードを起動する"
    )

    @Argument(help: "起動時に読み込む .paikei ファイル（省略可）")
    var path: String?

    func run() throws {
        var session = try Session()
        let interactive = isatty(STDIN_FILENO) != 0

        if let path {
            try session.load(path)
            print(SnapshotDescription.summary(of: session.state))
        } else if interactive {
            print("paikei 対話モード。`help` でコマンド一覧、`quit` で終了。")
        }

        while true {
            if interactive { printPrompt() }
            guard let line = readLine(strippingNewline: true) else { break }
            let words = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let name = words.first, !name.hasPrefix("#") else { continue }

            do {
                if try !ReplCommands.run(name, Array(words.dropFirst()), &session) { break }
            } catch {
                print("エラー: \(ReplCommands.message(for: error))")
            }
        }
    }

    /// プロンプトは改行しないので明示的に流す。
    private func printPrompt() {
        FileHandle.standardOutput.write(Data("> ".utf8))
    }
}
