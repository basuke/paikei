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
            throw StreamParseError.malformedJSON(line)
        }
        guard let type = fields["type"] as? String else {
            throw StreamParseError.missingField("type", eventType: "?")
        }
        let decoder = Decoder(fields: fields, format: format, type: type)

        switch type {
        case "tsumo":
            return .ツモ(手番: try decoder.player("actor"),
                        牌: try decoder.tileOrUnknown("pai"))
        case "dahai":
            return .打牌(手番: try decoder.player("actor"),
                        牌: try decoder.tile("pai"),
                        ツモ切り: fields["tsumogiri"] as? Bool)
        case "chi":
            return .チー(手番: try decoder.player("actor"),
                        牌: try decoder.tile("pai"),
                        手牌から: try decoder.tiles("consumed"))
        case "pon":
            return .ポン(手番: try decoder.player("actor"),
                        相手: try decoder.player("target"),
                        牌: try decoder.tile("pai"),
                        手牌から: try decoder.tiles("consumed"))
        case "daiminkan":
            return .大明槓(手番: try decoder.player("actor"),
                          相手: try decoder.player("target"),
                          牌: try decoder.tile("pai"),
                          手牌から: try decoder.tiles("consumed"))
        case "kakan":
            return .加槓(手番: try decoder.player("actor"), 牌: try decoder.tile("pai"))
        case "ankan":
            return .暗槓(手番: try decoder.player("actor"),
                        手牌から: try decoder.tiles("consumed"))
        case "reach":
            return .立直(手番: try decoder.player("actor"))
        case "reach_accepted":
            return .立直成立(手番: try decoder.player("actor"))
        case "dora":
            return .新ドラ(表示牌: try decoder.tile("dora_marker"))
        case "hora":
            return .和了(手番: try decoder.player("actor"),
                        相手: try decoder.player("target"),
                        牌: try decoder.tileIfPresent("pai"))
        case "ryukyoku":
            return .流局
        default:
            throw StreamParseError.unknownEventType(type)
        }
    }

    /// フィールドの取り出しと方言の解決。
    private struct Decoder {
        let fields: [String: Any]
        let format: StreamFormat
        let type: String

        func player(_ key: String) throws -> Player {
            guard let value = fields[key] else {
                throw StreamParseError.missingField(key, eventType: type)
            }
            switch format {
            case .paikei:
                guard let name = value as? String, let player = Player(rawValue: name) else {
                    throw StreamParseError.invalidValue(field: key, value: "\(value)")
                }
                return player
            case .mjai:
                guard let seat = value as? Int else {
                    throw StreamParseError.invalidValue(field: key, value: "\(value)")
                }
                return try format.player(fromSeat: seat)
            }
        }

        func tile(_ key: String) throws -> Tile {
            guard let tile = try tileIfPresent(key) else {
                throw StreamParseError.missingField(key, eventType: type)
            }
            return tile
        }

        /// `"?"`（観測できない牌）を nil として受理する。
        func tileOrUnknown(_ key: String) throws -> Tile? {
            guard let text = fields[key] as? String else {
                throw StreamParseError.missingField(key, eventType: type)
            }
            if text == "?" { return nil }
            return try parseTile(text, key: key)
        }

        func tileIfPresent(_ key: String) throws -> Tile? {
            guard let value = fields[key] else { return nil }
            guard let text = value as? String else {
                throw StreamParseError.invalidValue(field: key, value: "\(value)")
            }
            return try parseTile(text, key: key)
        }

        func tiles(_ key: String) throws -> [Tile] {
            guard let texts = fields[key] as? [String] else {
                throw StreamParseError.missingField(key, eventType: type)
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
                throw StreamParseError.invalidValue(field: key, value: text)
            }
            return tile
        }
    }

    // MARK: - シリアライズ（paikei 方言の正規形）

    static func line(for event: Event) -> String {
        var parts: [String] = []
        func add(_ key: String, _ value: String) { parts.append("\"\(key)\":\"\(value)\"") }
        func add(_ key: String, _ value: Bool) { parts.append("\"\(key)\":\(value)") }
        func add(_ key: String, tiles: [Tile]) {
            let items = tiles.map { "\"\($0.mpsz)\"" }.joined(separator: ",")
            parts.append("\"\(key)\":[\(items)]")
        }

        switch event {
        case let .ツモ(actor, tile):
            add("type", "tsumo"); add("actor", actor.rawValue)
            add("pai", tile?.mpsz ?? "?")
        case let .打牌(actor, tile, tsumogiri):
            add("type", "dahai"); add("actor", actor.rawValue); add("pai", tile.mpsz)
            if let tsumogiri { add("tsumogiri", tsumogiri) }
        case let .チー(actor, tile, consumed):
            add("type", "chi"); add("actor", actor.rawValue); add("pai", tile.mpsz)
            add("consumed", tiles: consumed)
        case let .ポン(actor, target, tile, consumed):
            add("type", "pon"); add("actor", actor.rawValue); add("target", target.rawValue)
            add("pai", tile.mpsz); add("consumed", tiles: consumed)
        case let .大明槓(actor, target, tile, consumed):
            add("type", "daiminkan"); add("actor", actor.rawValue); add("target", target.rawValue)
            add("pai", tile.mpsz); add("consumed", tiles: consumed)
        case let .加槓(actor, tile):
            add("type", "kakan"); add("actor", actor.rawValue); add("pai", tile.mpsz)
        case let .暗槓(actor, consumed):
            add("type", "ankan"); add("actor", actor.rawValue); add("consumed", tiles: consumed)
        case let .立直(actor):
            add("type", "reach"); add("actor", actor.rawValue)
        case let .立直成立(actor):
            add("type", "reach_accepted"); add("actor", actor.rawValue)
        case let .新ドラ(marker):
            add("type", "dora"); add("dora_marker", marker.mpsz)
        case let .和了(actor, target, tile):
            add("type", "hora"); add("actor", actor.rawValue); add("target", target.rawValue)
            if let tile { add("pai", tile.mpsz) }
        case .流局:
            add("type", "ryukyoku")
        }
        return "{\(parts.joined(separator: ","))}"
    }
}
