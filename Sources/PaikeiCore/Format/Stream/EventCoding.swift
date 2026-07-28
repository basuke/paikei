import Foundation

/// イベント1行（JSON Lines）のパースとシリアライズ（仕様§8.1〜8.2）。
///
/// パースは方言（paikei / mjai）を受理し、シリアライズは常に paikei 方言の
/// 正規形を出す。MJAI由来の余分なフィールド（点数移動など）は読み飛ばす。
enum EventCoding {
    // MARK: - パース

    static func event(fromLine line: String, format: StreamFormat) throws -> Event {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)),
              let fields = object as? [String: Any] else {
            throw StreamParseError.不正なJSON(line)
        }
        guard let type = fields["type"] as? String else {
            throw StreamParseError.フィールド欠落("type", イベント種別: "?")
        }
        let decoder = Decoder(fields: fields, format: format, type: type)

        switch type {
        case "tsumo":
            return .ツモ(of: try decoder.player("actor"),
                        牌: try decoder.tileOrUnknown("pai"))
        case "dahai":
            return .打牌(of: try decoder.player("actor"),
                        牌: try decoder.tile("pai"),
                        ツモ切り: fields["tsumogiri"] as? Bool)
        case "chi":
            return .チー(of: try decoder.player("actor"),
                        牌: try decoder.tile("pai"),
                        手牌から: try decoder.tiles("consumed"))
        case "pon":
            return .ポン(of: try decoder.player("actor"),
                        from: try decoder.player("target"),
                        牌: try decoder.tile("pai"),
                        手牌から: try decoder.tiles("consumed"))
        case "daiminkan":
            return .大明槓(of: try decoder.player("actor"),
                          from: try decoder.player("target"),
                          牌: try decoder.tile("pai"),
                          手牌から: try decoder.tiles("consumed"))
        case "kakan":
            return .加槓(of: try decoder.player("actor"), 牌: try decoder.tile("pai"))
        case "ankan":
            return .暗槓(of: try decoder.player("actor"),
                        手牌から: try decoder.tiles("consumed"))
        case "reach":
            return .立直(of: try decoder.player("actor"))
        case "reach_accepted":
            return .立直成立(of: try decoder.player("actor"))
        case "dora":
            return .新ドラ(表示牌: try decoder.tile("dora_marker"))
        case "hora":
            return .和了(of: try decoder.player("actor"),
                        from: try decoder.player("target"),
                        牌: try decoder.tileIfPresent("pai"))
        case "ryukyoku":
            return .流局(理由: (fields["reason"] as? String).map(RyukyokuReason.init(token:)))
        default:
            throw StreamParseError.未知のイベント種別(type)
        }
    }

    /// フィールドの取り出しと方言の解決。
    private struct Decoder {
        let fields: [String: Any]
        let format: StreamFormat
        let type: String

        func player(_ key: String) throws -> Player {
            guard let value = fields[key] else {
                throw StreamParseError.フィールド欠落(key, イベント種別: type)
            }
            switch format {
            case .paikei:
                guard let name = value as? String, let player = Player(rawValue: name) else {
                    throw StreamParseError.不正な値(フィールド: key, 値: "\(value)")
                }
                return player
            case .mjai:
                guard let seat = value as? Int else {
                    throw StreamParseError.不正な値(フィールド: key, 値: "\(value)")
                }
                return try format.player(fromSeat: seat)
            }
        }

        func tile(_ key: String) throws -> Tile {
            guard let tile = try tileIfPresent(key) else {
                throw StreamParseError.フィールド欠落(key, イベント種別: type)
            }
            return tile
        }

        /// `"?"`（観測できない牌）を nil として受理する。
        func tileOrUnknown(_ key: String) throws -> Tile? {
            guard let text = fields[key] as? String else {
                throw StreamParseError.フィールド欠落(key, イベント種別: type)
            }
            if text == "?" { return nil }
            return try parseTile(text, key: key)
        }

        func tileIfPresent(_ key: String) throws -> Tile? {
            guard let value = fields[key] else { return nil }
            guard let text = value as? String else {
                throw StreamParseError.不正な値(フィールド: key, 値: "\(value)")
            }
            return try parseTile(text, key: key)
        }

        func tiles(_ key: String) throws -> [Tile] {
            guard let texts = fields[key] as? [String] else {
                throw StreamParseError.フィールド欠落(key, イベント種別: type)
            }
            return try texts.map { try parseTile($0, key: key) }
        }

        private func parseTile(_ text: String, key: String) throws -> Tile {
            let tile: Tile?
            switch format {
            case .paikei: tile = try? Tile.parse(text)
            case .mjai: tile = Tile(mjai: text)
            }
            guard let tile else {
                throw StreamParseError.不正な値(フィールド: key, 値: text)
            }
            return tile
        }
    }

    // MARK: - シリアライズ

    /// `.paikei` 方言の正規形。`[stream]` の書き出しはこちら。
    static func line(for event: Event) -> String {
        line(for: event, format: .paikei)
    }

    /// 方言を指定して1行にする。mjai方言は bot が手を返すときに使う（フェーズ7）。
    static func line(for event: Event, format: StreamFormat) -> String {
        var out = Encoder(format: format)

        switch event {
        case let .ツモ(actor, tile):
            out.add("type", "tsumo"); out.add("actor", player: actor)
            out.add("pai", tile.map(out.notation) ?? "?")
        case let .打牌(actor, tile, tsumogiri):
            out.add("type", "dahai"); out.add("actor", player: actor); out.add("pai", tile: tile)
            if let tsumogiri { out.add("tsumogiri", tsumogiri) }
        case let .チー(actor, tile, consumed):
            out.add("type", "chi"); out.add("actor", player: actor); out.add("pai", tile: tile)
            out.add("consumed", tiles: consumed)
        case let .ポン(actor, target, tile, consumed):
            out.add("type", "pon"); out.add("actor", player: actor); out.add("target", player: target)
            out.add("pai", tile: tile); out.add("consumed", tiles: consumed)
        case let .大明槓(actor, target, tile, consumed):
            out.add("type", "daiminkan"); out.add("actor", player: actor)
            out.add("target", player: target)
            out.add("pai", tile: tile); out.add("consumed", tiles: consumed)
        case let .加槓(actor, tile):
            out.add("type", "kakan"); out.add("actor", player: actor); out.add("pai", tile: tile)
        case let .暗槓(actor, consumed):
            out.add("type", "ankan"); out.add("actor", player: actor)
            out.add("consumed", tiles: consumed)
        case let .立直(actor):
            out.add("type", "reach"); out.add("actor", player: actor)
        case let .立直成立(actor):
            out.add("type", "reach_accepted"); out.add("actor", player: actor)
        case let .新ドラ(marker):
            out.add("type", "dora"); out.add("dora_marker", tile: marker)
        case let .和了(actor, target, tile):
            out.add("type", "hora"); out.add("actor", player: actor); out.add("target", player: target)
            if let tile { out.add("pai", tile: tile) }
        case let .流局(reason):
            out.add("type", "ryukyoku")
            if let reason { out.add("reason", reason.token) }
        }
        return out.line
    }

    /// フィールドの組み立てと方言の解決（`Decoder` の対）。
    private struct Encoder {
        let format: StreamFormat
        private var parts: [String] = []

        init(format: StreamFormat) { self.format = format }

        var line: String { "{\(parts.joined(separator: ","))}" }

        func notation(_ tile: Tile) -> String {
            switch format {
            case .paikei: tile.mpsz
            case .mjai: tile.mjaiNotation
            }
        }

        mutating func add(_ key: String, _ value: String) {
            parts.append("\"\(key)\":\"\(value)\"")
        }

        mutating func add(_ key: String, _ value: Bool) {
            parts.append("\"\(key)\":\(value)")
        }

        mutating func add(_ key: String, tile: Tile) {
            add(key, notation(tile))
        }

        mutating func add(_ key: String, tiles: [Tile]) {
            let items = tiles.map { "\"\(notation($0))\"" }.joined(separator: ",")
            parts.append("\"\(key)\":[\(items)]")
        }

        mutating func add(_ key: String, player: Player) {
            if let seat = format.seat(of: player) {
                parts.append("\"\(key)\":\(seat)")
            } else {
                add(key, player.rawValue)
            }
        }
    }
}
