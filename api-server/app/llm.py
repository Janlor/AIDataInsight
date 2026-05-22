import json
from pathlib import Path
from typing import Any, Dict, Iterable, Optional, Protocol, Tuple

from .config import get_settings


class LLMProvider(Protocol):
    def analyze(self, question: str, history_id: int) -> Dict:
        ...

    def stream(self, question: str) -> Iterable[str]:
        ...


class MockLLMProvider:
    def analyze(self, question: str, history_id: int) -> Dict:
        fixture_result = load_function_fixture(question)
        if fixture_result is not None:
            result = dict(fixture_result)
            # Keep the local conversation flow coherent while preserving the
            # Apifox function name, msg, and arguments.
            result["historyId"] = history_id
            return result

        normalized = question.lower()
        if "你好" in question or "hello" in normalized:
            return {
                "historyId": history_id,
                "hasTool": False,
                "name": None,
                "msg": "你好，我可以帮你分析经营数据。",
                "arguments": None,
            }

        return {
            "historyId": history_id,
            "hasTool": True,
            "name": "querySalesGroupByMonth",
            "msg": None,
            "arguments": {
                "kind": "timeRange",
                "value": {
                    "startDate": "2026-01-01",
                    "endDate": "2026-01-31",
                    "orgId": 1,
                    "customerName": None,
                    "goodsType": None,
                    "orderType": None,
                    "operator": None,
                    "value": None,
                },
            },
        }

    def stream(self, question: str) -> Iterable[str]:
        if "你好" in question or "hello" in question.lower():
            yield "你好，"
            yield "我可以帮你分析经营数据。"
            return
        yield "已收到你的问题，"
        yield "我先用本地模拟分析结果完成这次流程。"


def chart_detail(function_name: Optional[str] = None) -> Dict:
    fixture_payload = load_chart_fixture(function_name)
    if fixture_payload is not None:
        return fixture_payload

    name = function_name or "querySalesGroupByMonth"
    return {
        "historyDetailId": None,
        "funcType": name,
        "chartCommonVoList": [
            {"bizId": "2026-01", "name": "2026-01", "value": 128800.5},
            {"bizId": "2026-02", "name": "2026-02", "value": 156300.25},
            {"bizId": "2026-03", "name": "2026-03", "value": 183420.75},
        ],
        "accountAgeGroupVoList": None,
    }


def compact_json(payload: Dict) -> str:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


FUNCTION_FIXTURES: Tuple[Tuple[Tuple[str, ...], str], ...] = (
    (("钢材存货金额余额最多的公司", "钢材", "存货"), "steel-inventory-highest-balance.json"),
    (("查看仓库中煤炭库存大于5万吨的公司", "煤炭", "5万吨"), "coal-stock-over-50000-tons.json"),
    (("查看各公司账龄超过180天的金额", "账龄", "180天"), "account-age-over-180-days.json"),
    (("列出公司FHJK应收余额超过5000万的客户", "FHJK", "5000万"), "fhjk-ar-over-50-million.json"),
    (("今年第三季度销售额大于2亿的公司", "第三季度", "2亿"), "q3-sales-over-200-million.json"),
)

CHART_FIXTURES = {
    "queryAccountAgeGroupByOrg": "account-age-by-org.json",
    "querySalesGroupByOrgAndGoodsType": "sales-by-org-and-goods-type.json",
    "queryArGroupByCustomer": "ar-by-customer.json",
    "queryInventoryGroupByOrg": "inventory-by-org.json",
    "queryStockGroupByOrg": "stock-by-org.json",
}


def load_function_fixture(question: str) -> Optional[Dict]:
    path = match_function_fixture(question)
    if path is None:
        return None
    payload = load_json_payload(path)
    data = unwrap_envelope(payload)
    return data if isinstance(data, dict) else None


def match_function_fixture(question: str) -> Optional[Path]:
    normalized = normalize_text(question)
    for keywords, filename in FUNCTION_FIXTURES:
        if all(normalize_text(keyword) in normalized for keyword in keywords):
            return get_settings().fixtures_dir / "chat" / "function" / filename
    return None


def load_chart_fixture(function_name: Optional[str]) -> Optional[Dict]:
    if not function_name:
        return None
    filename = CHART_FIXTURES.get(function_name)
    if filename is None:
        return None
    payload = load_json_payload(get_settings().fixtures_dir / "chart" / filename)
    data = unwrap_envelope(payload)
    return data if isinstance(data, dict) else None


def load_json_payload(path: Path) -> Optional[Any]:
    if not path.exists():
        return None
    raw = path.read_text(encoding="utf-8").strip()
    if not raw:
        return None
    return json.loads(raw)


def unwrap_envelope(payload: Optional[Any]) -> Optional[Any]:
    if isinstance(payload, dict) and "code" in payload and "data" in payload:
        return payload.get("data")
    return payload


def normalize_text(value: str) -> str:
    return value.lower().replace("？", "").replace("?", "").replace("，", "").replace(",", "").strip()
