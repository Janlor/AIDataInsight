from pathlib import Path

from fastapi.testclient import TestClient

from app.database import reset_engine_for_tests
from app.main import app


def make_client(tmp_path: Path) -> TestClient:
    reset_engine_for_tests("sqlite:///" + str(tmp_path / "test.db"))
    return TestClient(app)


def login(client: TestClient) -> str:
    response = client.post("/oauth2/login", json={"name": "demo", "pwd": "demo"})
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

        login_response = client.post("/oauth2/login", json={"name": "demo", "pwd": "demo"})
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
