/// ルールオプション（仕様§10の論点3、CLAUDE.md の既定値）。
///
/// ハードコードを避け、点数・役計算はこの構造体を参照する。
public struct RuleSet: Sendable, Equatable {
    /// 喰いタン（副露での断么九）を認めるか。
    public var kuitan: Bool
    /// 赤5ドラ（各スート1枚ずつ）を使うか。
    public var redFives: Bool
    /// 切り上げ満貫（30符4翻・60符3翻を満貫扱い）を認めるか。
    public var roundUpMangan: Bool
    /// 一発を認めるか。
    public var ippatsu: Bool
    /// 裏ドラを認めるか。
    public var uraDora: Bool
    /// 連風牌（場風かつ自風）の雀頭の符。伝統的に4、天鳳系は2。
    public var doubleWindPairFu: Int

    public init(
        kuitan: Bool = true,
        redFives: Bool = true,
        roundUpMangan: Bool = false,
        ippatsu: Bool = true,
        uraDora: Bool = true,
        doubleWindPairFu: Int = 4
    ) {
        self.kuitan = kuitan
        self.redFives = redFives
        self.roundUpMangan = roundUpMangan
        self.ippatsu = ippatsu
        self.uraDora = uraDora
        self.doubleWindPairFu = doubleWindPairFu
    }

    /// CLAUDE.md の既定値: 喰いタンあり・赤3枚・切り上げなし・一発/裏あり。
    public static let standard = RuleSet()
}
