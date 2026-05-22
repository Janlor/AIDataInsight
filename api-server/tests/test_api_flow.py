from pathlib import Path
import json

from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import reset_engine_for_tests
from app.main import app


def make_client(tmp_path: Path, fixtures_dir: Path = None, monkeypatch=None) -> TestClient:
    if fixtures_dir is not None and monkeypatch is not None:
        monkeypatch.setenv("AIDATAINSIGHT_FIXTURES_DIR", str(fixtures_dir))
        get_settings.cache_clear()
    reset_engine_for_tests("sqlite:///" + str(tmp_path / "test.db"), fixtures_dir=fixtures_dir)
    return TestClient(app)


def login(client: TestClient) -> str:
    response = client.post("/oauth2/login", json={"name": "demo", "pwd": "demo@123"})
    payload = response.json()
    assert payload["code"] == 200
    assert payload["data"]["access_token"]
    assert payload["data"]["refresh_token"]
    return payload["data"]["access_token"]


def auth_headers(token: str) -> dict:
    return {"Authorization": "Bearer " + token}


def test_login_refresh_and_protected_auth(tmp_path: Path) -> None:
    with make_client(tmp_path) as client:
        unauthorized = client.get("/oauth2/getUserInfo")
        assert unauthorized.status_code == 200
        assert unauthorized.json()["code"] == 401

        login_response = client.post("/oauth2/login", json={"name": "demo", "pwd": "demo@123"})
        login_payload = login_response.json()
        assert login_payload["code"] == 200
        assert login_payload["data"]["access_token"]
        assert login_payload["data"]["accessToken"] == login_payload["data"]["access_token"]

        refresh_response = client.get(
            "/oauth2/refresh",
            params={"refreshToken": login_payload["data"]["refresh_token"]},
        )
        refresh_payload = refresh_response.json()
        assert refresh_payload["code"] == 200
        assert refresh_payload["data"]["access_token"] != login_payload["data"]["access_token"]


def test_new_question_creates_history_and_detail_can_restore(tmp_path: Path) -> None:
    with make_client(tmp_path) as client:
        token = login(client)

        send_response = client.get(
            "/chat/function",
            params={"question": "查看一月销售额"},
            headers=auth_headers(token),
        )
        send_payload = send_response.json()
        assert send_payload["code"] == 200
        history_id = send_payload["data"]["historyId"]
        assert history_id

        page_payload = client.get(
            "/history/page",
            params={"currentPage": 1, "pageSize": 20},
            headers=auth_headers(token),
        ).json()
        assert page_payload["code"] == 200
        assert any(record["id"] == history_id for record in page_payload["data"]["records"])

        detail_payload = client.get(
            "/history/detail",
            params={"historyId": history_id},
            headers=auth_headers(token),
        ).json()
        assert detail_payload["code"] == 200
        details = detail_payload["data"]["detailList"]
        assert len(details) == 2
        assert details[0]["content"] == "查看一月销售额"
        assert details[1]["contentType"] == "2"


def test_existing_history_appends_messages(tmp_path: Path) -> None:
    with make_client(tmp_path) as client:
        token = login(client)
        first = client.get(
            "/chat/function",
            params={"question": "你好"},
            headers=auth_headers(token),
        ).json()
        history_id = first["data"]["historyId"]

        second = client.get(
            "/chat/function",
            params={"question": "继续查看一月销售额", "historyId": history_id},
            headers=auth_headers(token),
        ).json()
        assert second["data"]["historyId"] == history_id

        detail_payload = client.get(
            "/history/detail",
            params={"historyId": history_id},
            headers=auth_headers(token),
        ).json()
        assert len(detail_payload["data"]["detailList"]) == 4


def test_like_delete_and_delete_all_history(tmp_path: Path) -> None:
    with make_client(tmp_path) as client:
        token = login(client)
        created = client.get(
            "/chat/function",
            params={"question": "查看一月销售额"},
            headers=auth_headers(token),
        ).json()
        history_id = created["data"]["historyId"]
        details = client.get(
            "/history/detail",
            params={"historyId": history_id},
            headers=auth_headers(token),
        ).json()["data"]["detailList"]
        assistant_detail_id = details[1]["id"]

        like_payload = client.post(
            "/history/like",
            json={"historyDetailId": assistant_detail_id, "like": "1"},
            headers=auth_headers(token),
        ).json()
        assert like_payload["code"] == 200

        liked_detail = client.get(
            "/history/detail",
            params={"historyId": history_id},
            headers=auth_headers(token),
        ).json()["data"]["detailList"][1]
        assert liked_detail["isLike"] == "1"

        delete_payload = client.get(
            "/history/delete",
            params={"historyId": history_id},
            headers=auth_headers(token),
        ).json()
        assert delete_payload["code"] == 200
        deleted_detail = client.get(
            "/history/detail",
            params={"historyId": history_id},
            headers=auth_headers(token),
        ).json()
        assert deleted_detail["code"] == 404

        client.get(
            "/chat/function",
            params={"question": "你好"},
            headers=auth_headers(token),
        )
        clear_payload = client.get("/history/deleteAll", headers=auth_headers(token)).json()
        assert clear_payload["code"] == 200
        page_payload = client.get(
            "/history/page",
            params={"currentPage": 1, "pageSize": 20},
            headers=auth_headers(token),
        ).json()
        assert page_payload["data"]["total"] == 0


def test_stream_returns_sse_frames(tmp_path: Path) -> None:
    with make_client(tmp_path) as client:
        token = login(client)
        with client.stream(
            "GET",
            "/stream",
            params={"question": "你好"},
            headers=auth_headers(token),
        ) as response:
            body = "".join(response.iter_text())
        assert "data: 你好，" in body
        assert "data: [DONE]" in body


def test_startup_imports_apifox_history_fixtures(tmp_path: Path) -> None:
    fixtures_dir = tmp_path / "fixtures"
    detail_dir = fixtures_dir / "history" / "detail"
    detail_dir.mkdir(parents=True)
    (fixtures_dir / "history").mkdir(exist_ok=True)
    (fixtures_dir / "history" / "page.json").write_text(
        json.dumps(
            {
                "code": 200,
                "data": {
                    "records": [
                        {
                            "id": 9001,
                            "name": "Apifox seeded history",
                            "createTime": "2026-05-22 10:00:00",
                            "updateTime": "2026-05-22 10:01:00",
                        }
                    ]
                },
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    (detail_dir / "history-9001.json").write_text(
        json.dumps(
            {
                "code": 200,
                "data": {
                    "id": 9001,
                    "name": "Apifox seeded history",
                    "createTime": "2026-05-22 10:00:00",
                    "updateTime": "2026-05-22 10:01:00",
                    "detailList": [
                        {
                            "id": 9101,
                            "historyId": 9001,
                            "type": "1",
                            "contentType": "1",
                            "content": "来自 Apifox 的问题",
                            "createTime": "2026-05-22 10:00:00",
                            "updateTime": "2026-05-22 10:00:00",
                        },
                        {
                            "id": 9102,
                            "historyId": 9001,
                            "type": "2",
                            "contentType": "1",
                            "content": "{\"msg\":\"来自 Apifox 的回答\"}",
                            "createTime": "2026-05-22 10:01:00",
                            "updateTime": "2026-05-22 10:01:00",
                        },
                    ],
                },
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    with make_client(tmp_path, fixtures_dir=fixtures_dir) as client:
        token = login(client)
        page_payload = client.get(
            "/history/page",
            params={"currentPage": 1, "pageSize": 20},
            headers=auth_headers(token),
        ).json()
        assert page_payload["data"]["total"] == 1
        assert page_payload["data"]["records"][0]["id"] == 9001

        detail_payload = client.get(
            "/history/detail",
            params={"historyId": 9001},
            headers=auth_headers(token),
        ).json()
        assert detail_payload["data"]["detailList"][0]["content"] == "来自 Apifox 的问题"


def test_recommended_question_uses_function_and_chart_fixtures(tmp_path: Path, monkeypatch) -> None:
    fixtures_dir = tmp_path / "fixtures"
    function_dir = fixtures_dir / "chat" / "function"
    chart_dir = fixtures_dir / "chart"
    function_dir.mkdir(parents=True)
    chart_dir.mkdir(parents=True)

    (function_dir / "steel-inventory-highest-balance.json").write_text(
        json.dumps(
            {
                "code": 200,
                "msg": "success",
                "data": {
                    "historyId": 48,
                    "hasTool": True,
                    "name": "queryInventoryGroupByOrg",
                    "msg": "识别成功",
                    "arguments": {
                        "orgId": 1,
                        "goodsType": 14001,
                        "orderType": "desc",
                        "operator": ">",
                        "value": 100000,
                    },
                },
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    (chart_dir / "inventory-by-org.json").write_text(
        json.dumps(
            {
                "code": 200,
                "msg": "OK",
                "data": {
                    "funcType": "queryInventoryGroupByOrg",
                    "historyDetailId": 238,
                    "chartCommonVoList": [
                        {"bizId": "1003", "name": "公司FHLC", "value": 1618146904.11}
                    ],
                    "accountAgeGroupVoList": None,
                },
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    with make_client(tmp_path, fixtures_dir=fixtures_dir, monkeypatch=monkeypatch) as client:
        token = login(client)
        function_payload = client.get(
            "/chat/function",
            params={"question": "钢材存货金额余额最多的公司？"},
            headers=auth_headers(token),
        ).json()

        assert function_payload["code"] == 200
        assert function_payload["data"]["name"] == "queryInventoryGroupByOrg"
        assert function_payload["data"]["arguments"]["goodsType"] == 14001
        assert function_payload["data"]["historyId"] != 48

        chart_payload = client.get(
            "/chart/queryInventoryGroupByOrg",
            params={"historyId": function_payload["data"]["historyId"]},
            headers=auth_headers(token),
        ).json()
        assert chart_payload["data"]["funcType"] == "queryInventoryGroupByOrg"
        assert chart_payload["data"]["chartCommonVoList"][0]["name"] == "公司FHLC"
