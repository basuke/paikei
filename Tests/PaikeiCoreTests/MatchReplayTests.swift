import Testing
import Foundation
@testable import PaikeiCore

/// MJAI 生ログを `Match` として通す経路。`MjaiSession` → `結末()` → `Match` を繋ぐ。
///
/// `.paikei` は1局が単位（仕様§10の論点7）なので、複数局を流せる入力は MJAI の
/// 生ログだけ。半荘を通した検証はここが受け持つ。
@Suite("MJAIログから対局を組み立てる")
struct MJAIログから対局を組み立てる {
    func 行(_ name: String) throws -> [String] {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "jsonl", subdirectory: "Fixtures"),
            "fixture \(name).jsonl が見つからない")
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n").map(String.init)
    }

    /// ログを流して、終わった局を `Match` に積む。
    func 対局(_ name: String) throws -> (match: Match, 結末: [GameResultAnalysis]) {
        var session = MjaiSession()
        var match: Match?
        var results: [GameResultAnalysis] = []

        for line in try 行(name) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            switch try session.receive(line) {
            case let .局開始(snapshot):
                if match == nil {
                    let dealer = try #require(
                        Player.allCases.first { snapshot.players[$0]?.席風 == .東 })
                    match = Match(firstDealer: dealer)
                }
            case let .局終了(ended):
                guard let timeline = ended else { continue }
                let analysis = try timeline.結末()
                results.append(analysis)
                if case let .結末(result, _) = analysis {
                    try match?.finish(timeline, result: result)
                }
            default:
                break
            }
        }
        return (try #require(match), results)
    }

    @Test("2局を通して持ち点が動き、連荘する")
    func 半荘を通す() throws {
        let (match, 結末) = try 対局("hanchan")
        #expect(match.records.count == 2)

        // 東1局: 親の門前ツモ + 一気通貫 = 3翻30符、2000オール。
        guard case let .結末(.和了(winner, from, score), 仮定) = 結末[0] else {
            Issue.record("1局目は和了になるはず: \(結末[0])"); return
        }
        #expect(winner == .自分)
        #expect(from == .自分)
        #expect(score.翻 == 3)
        #expect(score.符 == 30)
        #expect(score.payment == .ツモ(親: nil, 子: 2000))
        #expect(仮定.isEmpty)

        // 東1局1本場: 荒牌平局。下家だけノーテンなので罰符は下家から3000。
        guard case let .結末(.流局(理由, テンパイ, 流し満貫), _) = 結末[1] else {
            Issue.record("2局目は流局になるはず: \(結末[1])"); return
        }
        #expect(理由 == .荒牌平局)
        #expect(テンパイ == [.自分, .対面, .上家])
        #expect(流し満貫.isEmpty)

        // 31000 + 1000、23000 - 3000、23000 + 1000 ×2。
        #expect(match.state.scores[.自分] == 32000)
        #expect(match.state.scores[.下家] == 20000)
        #expect(match.state.scores[.対面] == 24000)
        #expect(match.state.scores[.上家] == 24000)
        #expect(match.standings == [.自分, .対面, .上家, .下家])
    }

    @Test("親の和了とテンパイで連荘し、本場が積まれる")
    func 連荘して本場が積まれる() throws {
        let (match, _) = try 対局("hanchan")
        // 東1局（親の和了）→ 1本場（親テンパイの流局）→ 2本場へ。
        #expect(match.state.場風 == .東)
        #expect(match.state.局 == 1)
        #expect(match.state.本場 == 2)
        #expect(match.state.dealer == .自分)
        #expect(!match.終局済みか)
    }

    @Test("ログが持っている持ち点と、こちらの計算が一致する")
    func ログの持ち点と一致する() throws {
        // MJAI の start_kyoku は各局の開始時点の持ち点を持っている。前局を終えた
        // 時点の Match.state と突き合わせれば、点数移動の実装をログ自身で検証できる。
        var session = MjaiSession()
        var match: Match?
        var 照合した回数 = 0

        for line in try 行("hanchan") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            switch try session.receive(line) {
            case let .局開始(snapshot):
                guard let match else {
                    let dealer = try #require(
                        Player.allCases.first { snapshot.players[$0]?.席風 == .東 })
                    match = Match(firstDealer: dealer)
                    continue
                }
                for player in Player.allCases {
                    guard let ログ = snapshot.players[player]?.score else { continue }
                    #expect(ログ == match.state.scores[player], "\(player)")
                    照合した回数 += 1
                }
            case let .局終了(ended):
                guard let timeline = ended,
                      case let .結末(result, _) = try timeline.結末() else { continue }
                try match?.finish(timeline, result: result)
            default:
                break
            }
        }
        #expect(照合した回数 == 4)   // 2局目の配牌で4人ぶん
    }
}
