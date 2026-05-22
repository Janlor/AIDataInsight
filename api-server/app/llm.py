import json
from typing import Dict, Iterable, Optional, Protocol


class LLMProvider(Protocol):
    def analyze(self, question: str, history_id: int) -> Dict:
        ...

    def stream(self, question: str) -> Iterable[str]:
        ...


class MockLLMProvider:
    def analyze(self, question: str, history_id: int) -> Dict:
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
