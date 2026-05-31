/// 后端统一响应信封，业务数据位于 data，trace/tid 用于链路排查。
public struct APIResponseEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
    public let code: Int
    public let msg: String
    public let data: Payload?
    public let trace: String?
    public let tid: String?

    public init(code: Int, msg: String, data: Payload?, trace: String? = nil, tid: String? = nil) {
        self.code = code
        self.msg = msg
        self.data = data
        self.trace = trace
        self.tid = tid
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case msg
        case data
        case trace
        case tid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 200
        msg = try container.decodeIfPresent(String.self, forKey: .msg) ?? ""
        data = try container.decodeIfPresent(Payload.self, forKey: .data)
        trace = try container.decodeIfPresent(String.self, forKey: .trace)
        tid = try container.decodeIfPresent(String.self, forKey: .tid)
    }
}
