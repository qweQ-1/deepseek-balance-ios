import Foundation

/// DeepSeek 余额接口（GET /user/balance）的返回结构。
struct BalanceResponse: Decodable, Equatable {
    /// 单个币种的余额信息。
    struct Info: Decodable, Equatable, Hashable {
        let currency: String
        let totalBalance: String
        /// 赠送余额；接口偶尔缺字段，缺了就是 nil。
        let grantedBalance: String?
        /// 充值余额；同上。
        let toppedUpBalance: String?

        private enum CodingKeys: String, CodingKey {
            case currency
            case totalBalance = "total_balance"
            case grantedBalance = "granted_balance"
            case toppedUpBalance = "topped_up_balance"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
            totalBalance = Self.amountString(from: container, forKey: .totalBalance) ?? "-"
            grantedBalance = Self.amountString(from: container, forKey: .grantedBalance)
            toppedUpBalance = Self.amountString(from: container, forKey: .toppedUpBalance)
        }

        /// 金额可能是字符串（"110.00"）也可能是数字（110.0），两种都接受，统一存成字符串。
        private static func amountString(
            from container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) -> String? {
            if let string = try? container.decode(String.self, forKey: key) {
                return string
            }
            if let number = try? container.decode(Double.self, forKey: key) {
                return String(format: "%.2f", number)
            }
            return nil
        }
    }

    let isAvailable: Bool
    let balanceInfos: [Info]

    private enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

/// 金额显示格式。
enum CurrencyFormat {
    static func symbol(for currency: String) -> String {
        switch currency.uppercased() {
        case "CNY", "RMB":
            return "¥"
        case "USD":
            return "$"
        default:
            return ""
        }
    }

    static func display(amount: String, currency: String) -> String {
        let symbol = symbol(for: currency)
        if symbol.isEmpty {
            return currency.isEmpty ? amount : "\(amount) \(currency)"
        }
        return symbol + amount
    }
}

extension BalanceResponse.Info {
    var currencySymbol: String { CurrencyFormat.symbol(for: currency) }

    var toppedUpBalanceText: String {
        toppedUpBalance.map { CurrencyFormat.display(amount: $0, currency: currency) } ?? "—"
    }

    var grantedBalanceText: String {
        grantedBalance.map { CurrencyFormat.display(amount: $0, currency: currency) } ?? "—"
    }
}
