/// スナップショットのパースに関するエラー（仕様§3〜§6）。
public enum SnapshotParseError: Error, Equatable, Sendable {
    case 未知のセクション(String)
    case 未知のフィールド(キー: String, セクション: String)
    case 不正な値(キー: String, 値: String)
    case 不正な行(String)
    case 不正なヘッダ(String)
}

/// `.paikei` テキスト（スナップショット部）を `GameState` にパースする。
///
/// 依存方向は Format → ドメイン層 の一方向（仕様の設計原則）。`[stream]` 以降は
/// フェーズ6で扱うため、ここでは読み飛ばす。
public enum SnapshotParser {
    public static func parse(_ text: some StringProtocol) throws -> GameState {
        var state = GameState()
        var current: Player?  // nil = 卓全体セクション
        let source = String(text)

        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripComment(rawLine)
            if line.isEmpty { continue }

            if line.first == "[" {
                if line.hasPrefix("[stream]") { break }  // フェーズ6で対応
                current = try applyHeader(line, into: &state)
                continue
            }

            guard let colon = line.firstIndex(of: ":") else {
                throw SnapshotParseError.不正な行(String(line))
            }
            let key = String(line[..<colon].trimmingWhitespace())
            let value = line[line.index(after: colon)...].trimmingWhitespace()

            // 振り分けは位置ではなくキーで行う。
            // - プレイヤーフィールドはセクション無し（最小形§9.1）なら暗黙で self。
            // - 卓フィールド（claim_tile 含む）はプレイヤーセクションの後に来ても卓に属す。
            if playerFieldKeys.contains(key) {
                let player = current ?? .自分
                current = player
                try applyPlayerField(key: key, value: value, player: player, into: &state)
            } else {
                try applyTableField(key: key, value: value, into: &state)
            }
        }
        return state
    }

    private static let playerFieldKeys: Set<String> =
        ["hand", "draw", "melds", "river", "riichi", "score", "discard_context"]

    // MARK: - 行の前処理

    /// 行末までのコメント（`#` 以降）を除去し前後空白を落とす。
    private static func stripComment(_ line: Substring) -> Substring {
        line.prefix(while: { $0 != "#" }).trimmingWhitespace()
    }

    // MARK: - セクションヘッダ

    /// `[shimocha] seat=N` 形式を解釈し、対象プレイヤーを返す。
    private static func applyHeader(_ line: Substring, into state: inout GameState) throws -> Player {
        guard let close = line.firstIndex(of: "]"), line.first == "[" else {
            throw SnapshotParseError.不正なヘッダ(String(line))
        }
        let name = String(line[line.index(after: line.startIndex)..<close])
        guard let player = Player(rawValue: name) else {
            throw SnapshotParseError.未知のセクション(name)
        }

        var ps = state.players[player] ?? PlayerState()
        for token in line[line.index(after: close)...].split(whereSeparator: { $0.isWhitespace }) {
            let pair = token.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else {
                throw SnapshotParseError.不正なヘッダ(String(line))
            }
            switch String(pair[0]) {
            case "seat":
                ps.seat = try parseWind(key: "seat", value: pair[1])
            default:
                throw SnapshotParseError.未知のフィールド(キー: String(pair[0]), セクション: name)
            }
        }
        state.players[player] = ps
        return player
    }

    // MARK: - 卓全体フィールド（§3.1 / §3.4）

    private static func applyTableField(key: String, value: Substring, into state: inout GameState) throws {
        switch key {
        case "bakaze": state.場風 = try parseWind(key: key, value: value)
        case "kyoku": state.局 = try parseInt(key: key, value: value)
        case "honba": state.本場 = try parseInt(key: key, value: value)
        case "kyotaku": state.供託 = try parseInt(key: key, value: value)
        case "wall": state.wall = try parseInt(key: key, value: value)
        case "dora_markers": state.doraMarkers = try parseTileList(key: key, value: value)
        case "rule": state.rule = isUnknown(value) ? nil : String(value)
        case "claim_tile": state.claim = try parseClaim(value)
        default:
            throw SnapshotParseError.未知のフィールド(キー: key, セクション: "table")
        }
    }

    // MARK: - プレイヤーフィールド（§3.3）

    private static func applyPlayerField(
        key: String, value: Substring, player: Player, into state: inout GameState
    ) throws {
        var ps = state.players[player] ?? PlayerState()
        switch key {
        case "hand":
            ps.hand = isUnknown(value) ? nil : try wrapTile(key: key, value: value) { try Tile.parseHand($0).sorted() }
        case "draw":
            ps.draw = isUnknown(value) ? nil : try wrapTile(key: key, value: value) { try Tile.parse($0) }
        case "melds":
            ps.melds = try value.split(whereSeparator: { $0.isWhitespace }).map {
                do { return try Meld.parse($0) }
                catch { throw SnapshotParseError.不正な値(キー: key, 値: String(value)) }
            }
        case "river":
            do { ps.river = try RiverTile.parseLine(value) }
            catch { throw SnapshotParseError.不正な値(キー: key, 値: String(value)) }
        case "riichi":
            ps.riichi = try parseBool(key: key, value: value)
        case "score":
            ps.score = try parseInt(key: key, value: value)
        case "discard_context":
            if isUnknown(value) { ps.discardOrigin = nil }
            else if let origin = DiscardOrigin(rawValue: String(value)) { ps.discardOrigin = origin }
            else { throw SnapshotParseError.不正な値(キー: key, 値: String(value)) }
        default:
            throw SnapshotParseError.未知のフィールド(キー: key, セクション: player.rawValue)
        }
        state.players[player] = ps
    }

    // MARK: - claim_tile（§3.4）

    /// `6p from=shimocha kind=discard` を解釈する。
    private static func parseClaim(_ value: Substring) throws -> ClaimTile {
        func fail() -> SnapshotParseError { .不正な値(キー: "claim_tile", 値: String(value)) }
        let tokens = value.split(whereSeparator: { $0.isWhitespace })
        guard let first = tokens.first else { throw fail() }
        let tile: Tile
        do { tile = try Tile.parse(first) } catch { throw fail() }

        var from: Player?
        var kind: ClaimTile.Kind = .打牌
        for token in tokens.dropFirst() {
            let pair = token.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { throw fail() }
            switch String(pair[0]) {
            case "from":
                guard let p = Player(rawValue: String(pair[1])) else { throw fail() }
                from = p
            case "kind":
                guard let k = ClaimTile.Kind(rawValue: String(pair[1])) else { throw fail() }
                kind = k
            default: throw fail()
            }
        }
        guard let from else { throw fail() }
        return ClaimTile(tile: tile, from: from, kind: kind)
    }

    // MARK: - 値パーサー

    private static func isUnknown(_ value: Substring) -> Bool { value == "?" }

    private static func parseWind(key: String, value: Substring) throws -> Wind? {
        if isUnknown(value) { return nil }
        guard let wind = Wind(rawValue: String(value)) else {
            throw SnapshotParseError.不正な値(キー: key, 値: String(value))
        }
        return wind
    }

    private static func parseInt(key: String, value: Substring) throws -> Int? {
        if isUnknown(value) { return nil }
        guard let n = Int(value) else {
            throw SnapshotParseError.不正な値(キー: key, 値: String(value))
        }
        return n
    }

    private static func parseBool(key: String, value: Substring) throws -> Bool? {
        switch value {
        case "?": return nil
        case "true": return true
        case "false": return false
        default: throw SnapshotParseError.不正な値(キー: key, 値: String(value))
        }
    }

    private static func parseTileList(key: String, value: Substring) throws -> [Tile] {
        if isUnknown(value) { return [] }
        return try value.split(whereSeparator: { $0.isWhitespace }).map {
            do { return try Tile.parse($0) }
            catch { throw SnapshotParseError.不正な値(キー: key, 値: String(value)) }
        }
    }

    /// Tile 系パースの失敗を SnapshotParseError に包み直す。
    private static func wrapTile<T>(
        key: String, value: Substring, _ body: (Substring) throws -> T
    ) throws -> T {
        do { return try body(value) }
        catch { throw SnapshotParseError.不正な値(キー: key, 値: String(value)) }
    }
}
