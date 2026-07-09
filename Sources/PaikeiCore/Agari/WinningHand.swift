/// 役・符計算の入力。1つの和了手を「1通りの読み方」で束ねたもの。
///
/// 一般形は分解ごとに1つ作られ、上位（高点法）で最良を選ぶ。
public struct WinningHand: Sendable {
    public let form: AgariForm
    /// 一般形の分解。七対子・国士では nil。
    public let decomposition: HandDecomposition?
    /// 副露。
    public let melds: [Meld]
    /// 全14枚（槓は4枚分）。正規化済み。役の牌集合判定に使う。
    public let allTiles: [Tile]
    /// 面前か（副露なし。暗槓は面前を保つ）。
    public let isMenzen: Bool
    public let context: WinContext
    public let rules: RuleSet
}

extension Agari {
    /// 和了手を全ての読み方で束ねて返す。和了していなければ空。
    ///
    /// `concealed` は純手牌 + 和了牌（14 − 3×副露 枚）。
    public static func winningHands(
        concealed: [Tile], melds: [Meld], context: WinContext, rules: RuleSet
    ) -> [WinningHand] {
        let isMenzen = melds.allSatisfy { $0.kind == .ankan }
        var hands: [WinningHand] = []

        if Decomposition.isThirteenOrphans(concealed: concealed, melds: melds) {
            hands.append(WinningHand(
                form: .thirteenOrphans, decomposition: nil, melds: melds,
                allTiles: concealed.map(\.normalized), isMenzen: isMenzen,
                context: context, rules: rules))
        }
        if Decomposition.isSevenPairs(concealed: concealed, melds: melds) {
            hands.append(WinningHand(
                form: .sevenPairs, decomposition: nil, melds: melds,
                allTiles: concealed.map(\.normalized), isMenzen: isMenzen,
                context: context, rules: rules))
        }
        for decomposition in Decomposition.standard(concealed: concealed, melds: melds) {
            let all = decomposition.sets.flatMap(\.tiles) + decomposition.pair.tiles
            hands.append(WinningHand(
                form: .standard, decomposition: decomposition, melds: melds,
                allTiles: all, isMenzen: isMenzen, context: context, rules: rules))
        }
        return hands
    }
}

/// 和了計算の名前空間。
public enum Agari {}
