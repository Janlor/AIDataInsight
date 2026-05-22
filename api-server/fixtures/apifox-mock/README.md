# Apifox Mock Fixtures

These JSON files are machine-readable fixtures for `api-server`.

Seed behavior:

- `history/page.json` and `history/detail/*.json` are imported when a fresh local database is created.
- `chat/function/*.json` and `chart/*.json` are read at request time so recommended questions return distinct Apifox-backed results.
- Envelope responses with `code`, `msg`, and `data` are supported. The loader reads `data` automatically.

## Mapping

- `/oauth2/login` -> `oauth2/login.json`
- `/oauth2/getUserInfo` -> `oauth2/get-user-info.json`
- `/chat/template` -> `chat/template.json`
- `/chat/function`, `question=钢材存货金额余额最多的公司` -> `chat/function/steel-inventory-highest-balance.json`
- `/chat/function`, `question=查看仓库中煤炭库存大于5万吨的公司` -> `chat/function/coal-stock-over-50000-tons.json`
- `/chat/function`, `question=查看各公司账龄超过180天的金额` -> `chat/function/account-age-over-180-days.json`
- `/chat/function`, `question=列出公司FHJK应收余额超过5000万的客户` -> `chat/function/fhjk-ar-over-50-million.json`
- `/chat/function`, `question=今年第三季度销售额大于2亿的公司` -> `chat/function/q3-sales-over-200-million.json`
- `/chart/{name}`, `name=queryAccountAgeGroupByOrg` -> `chart/account-age-by-org.json`
- `/chart/{name}`, `name=querySalesGroupByOrgAndGoodsType` -> `chart/sales-by-org-and-goods-type.json`
- `/chart/{name}`, `name=queryArGroupByCustomer` -> `chart/ar-by-customer.json`
- `/chart/{name}`, `name=queryInventoryGroupByOrg` -> `chart/inventory-by-org.json`
- `/chart/{name}`, `name=queryStockGroupByOrg` -> `chart/stock-by-org.json`
- `/history/page` -> `history/page.json`
- `/history/detail`, `historyId=2` -> `history/detail/history-2.json`
- `/history/detail`, `historyId=11` -> `history/detail/history-11.json`
- `/history/detail`, `historyId=34` -> `history/detail/history-34.json`
- `/history/detail`, `historyId=36` -> `history/detail/history-36.json`
- `/history/detail`, `historyId=44` -> `history/detail/history-44.json`
- `/history/detail`, `historyId=45` -> `history/detail/history-45.json`
- `/history/detail`, `historyId=46` -> `history/detail/history-46.json`
- `/history/detail`, `historyId=48` -> `history/detail/history-48.json`
- `/history/detail`, `historyId=55` -> `history/detail/history-55.json`
