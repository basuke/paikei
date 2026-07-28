/// MJAIの `start_kyoku` を初期局面（t0）へ変換する（仕様§8.4）。
///
/// 配牌時点は「不明」がほとんど無い唯一の局面 — 場風・席風・持ち点・供託・本場・
/// ドラ表示牌が全て確定し、立直も全員していないと言い切れる。
/// つまりここから起こしたスナップショットは、解析が仮定を置かずに済む。
enum MjaiKyoku {
    /// 王牌14枚と配牌52枚を引いた、配牌直後の山の残り。
    static let wallAfterDeal = 136 - 14 - 13 * 4

    static func snapshot(from fields: [String: Any], selfActor: Int) throws -> GameState {
        let format = StreamFormat.mjai(selfActor: selfActor)

        func int(_ key: String) throws -> Int {
            guard let value = fields[key] as? Int else {
                throw StreamParseError.フィールド欠落(key, イベント種別: "start_kyoku")
            }
            return value
        }

        guard let text = fields["bakaze"] as? String, let bakaze = Wind(rawValue: text) else {
            throw StreamParseError.不正な値(フィールド: "bakaze", 値: "\(fields["bakaze"] ?? "")")
        }
        let oya = try int("oya")
        guard (0...3).contains(oya) else {
            throw StreamParseError.不正な値(フィールド: "oya", 値: String(oya))
        }

        let scores = fields["scores"] as? [Int] ?? []
        let hands = fields["tehais"] as? [[String]] ?? []

        var players: [Player: PlayerState] = [:]
        for seat in 0...3 {
            players[try format.player(fromSeat: seat)] = PlayerState(
                // 親を東として席風が決まる。MJAIの座順は反時計回り（仕様§8.2）。
                seat: Wind.allCases[(seat - oya + 4) % 4],
                hand: hands.indices.contains(seat) ? try hand(hands[seat]) : nil,
                // 配牌直後なので、誰も立直していないと言い切れる。
                riichi: false,
                score: scores.indices.contains(seat) ? scores[seat] : nil)
        }

        var markers: [Tile] = []
        if let text = fields["dora_marker"] as? String {
            guard let marker = Tile(mjai: text) else {
                throw StreamParseError.不正な値(フィールド: "dora_marker", 値: text)
            }
            markers = [marker]
        }

        return GameState(
            bakaze: bakaze, kyoku: try int("kyoku"), honba: try int("honba"),
            kyotaku: try int("kyotaku"), doraMarkers: markers, wall: wallAfterDeal,
            players: players)
    }

    /// 配牌13枚。全て `"?"`（他家の手牌）なら不明として nil を返す。
    private static func hand(_ texts: [String]) throws -> [Tile]? {
        if texts.allSatisfy({ $0 == "?" }) { return nil }
        return try texts.map {
            guard let tile = Tile(mjai: $0) else {
                throw StreamParseError.不正な値(フィールド: "tehais", 値: $0)
            }
            return tile
        }.sorted()
    }
}
