/// 和了の種類。
public enum WinType: Sendable, Equatable {
    case ツモ
    case ロン
}

/// 和了手の形。
public enum AgariForm: Sendable, Equatable {
    /// 4面子1雀頭。
    case 一般形
    case 七対子
    case 国士無双
}

/// `WinContext` の文脈フラグの矛盾。麻雀のルール上ありえない組み合わせを表す。
///
/// 観測の不足（`Requirement`）とは別物で、これは**呼び出し側の入力の誤り**。
/// 解析は矛盾を黙って握りつぶさず、`WinContextError` で拒む。
///
/// **風に依存する組み合わせはここに入れない**。`GameState.score` は不明な風を
/// 総当たりするため、矛盾検査は代表の風1つで済ませている（仕様§6）。
/// 「親の第一巡ロン」のような風次第の不整合は、矛盾ではなく役が付かないこととして扱う。
public enum WinContextContradiction: Sendable, Equatable {
    /// 一発には立直（ダブル立直を含む）が必要。
    case 立直なしの一発
    /// 嶺上開花はツモ和了のみ。
    case ロンの嶺上開花
    /// 槍槓はロン和了のみ。
    case ツモの槍槓
}

/// 矛盾した `WinContext` で解析を呼んだときのエラー。見つかった矛盾を全て持つ。
public struct WinContextError: Error, Equatable, Sendable {
    public let contradictions: [WinContextContradiction]

    public init(contradictions: [WinContextContradiction]) {
        self.contradictions = contradictions
    }
}

/// 和了計算に必要な、手牌からは読み取れない文脈情報（仕様§1の履歴層など）。
///
/// 一発・海底などの履歴依存情報は、スナップショットに持たず解析時に与える（仕様§10-1）。
public struct WinContext: Sendable, Equatable {
    /// 自風。
    public var seatWind: Wind
    /// 場風。
    public var roundWind: Wind
    /// 和了の種類。
    public var winType: WinType
    /// 和了牌（14枚目）。
    public var winningTile: Tile

    /// 立直。
    public var 立直: Bool
    /// ダブル立直。
    public var ダブル立直: Bool
    /// 一発。
    public var 一発: Bool
    /// 海底摸月 / 河底撈魚。
    public var lastTile: Bool
    /// 嶺上開花。
    public var afterKan: Bool
    /// 槍槓。
    public var robbingKan: Bool
    /// 配牌後の第一巡で、自分はまだ何もしていない。
    /// ツモなら天和（親）/ 地和（子）、ロンなら人和になる。
    public var firstTurn: Bool

    /// ドラ表示牌。
    public var doraMarkers: [Tile]
    /// 裏ドラ表示牌。
    public var uraMarkers: [Tile]

    public init(
        seatWind: Wind,
        roundWind: Wind,
        winType: WinType,
        winningTile: Tile,
        立直: Bool = false,
        ダブル立直: Bool = false,
        一発: Bool = false,
        lastTile: Bool = false,
        afterKan: Bool = false,
        robbingKan: Bool = false,
        firstTurn: Bool = false,
        doraMarkers: [Tile] = [],
        uraMarkers: [Tile] = []
    ) {
        self.seatWind = seatWind
        self.roundWind = roundWind
        self.winType = winType
        self.winningTile = winningTile
        self.立直 = 立直
        self.ダブル立直 = ダブル立直
        self.一発 = 一発
        self.lastTile = lastTile
        self.afterKan = afterKan
        self.robbingKan = robbingKan
        self.firstTurn = firstTurn
        self.doraMarkers = doraMarkers
        self.uraMarkers = uraMarkers
    }
}

extension WinContext {
    /// 文脈フラグの矛盾を列挙する。空なら整合している。
    public var contradictions: [WinContextContradiction] {
        var result: [WinContextContradiction] = []
        if 一発 && !(立直 || ダブル立直) { result.append(.立直なしの一発) }
        if afterKan && winType != .ツモ { result.append(.ロンの嶺上開花) }
        if robbingKan && winType != .ロン { result.append(.ツモの槍槓) }
        return result
    }

    /// 矛盾があれば `WinContextError` を投げる。役判定の入口で呼ばれる。
    public func validate() throws {
        let found = contradictions
        guard found.isEmpty else { throw WinContextError(contradictions: found) }
    }
}
