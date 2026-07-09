/// 和了の種類。
public enum WinType: Sendable, Equatable {
    case tsumo  // 自摸
    case ron    // 栄和
}

/// 和了手の形。
public enum AgariForm: Sendable, Equatable {
    case standard        // 一般形（4面子1雀頭）
    case sevenPairs      // 七対子
    case thirteenOrphans // 国士無双
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
    public var riichi: Bool
    /// ダブル立直。
    public var doubleRiichi: Bool
    /// 一発。
    public var ippatsu: Bool
    /// 海底摸月 / 河底撈魚。
    public var lastTile: Bool
    /// 嶺上開花。
    public var afterKan: Bool
    /// 槍槓。
    public var robbingKan: Bool

    /// ドラ表示牌。
    public var doraMarkers: [Tile]
    /// 裏ドラ表示牌。
    public var uraMarkers: [Tile]

    public init(
        seatWind: Wind,
        roundWind: Wind,
        winType: WinType,
        winningTile: Tile,
        riichi: Bool = false,
        doubleRiichi: Bool = false,
        ippatsu: Bool = false,
        lastTile: Bool = false,
        afterKan: Bool = false,
        robbingKan: Bool = false,
        doraMarkers: [Tile] = [],
        uraMarkers: [Tile] = []
    ) {
        self.seatWind = seatWind
        self.roundWind = roundWind
        self.winType = winType
        self.winningTile = winningTile
        self.riichi = riichi
        self.doubleRiichi = doubleRiichi
        self.ippatsu = ippatsu
        self.lastTile = lastTile
        self.afterKan = afterKan
        self.robbingKan = robbingKan
        self.doraMarkers = doraMarkers
        self.uraMarkers = uraMarkers
    }
}
