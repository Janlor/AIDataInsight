from functools import lru_cache
from pathlib import Path
from typing import Optional
import os


class Settings:
    """应用配置入口，集中解析数据目录、夹具目录和数据库地址。"""

    def __init__(self, database_url: Optional[str] = None) -> None:
        base_dir = Path(__file__).resolve().parents[1]
        self.base_dir = base_dir
        self.data_dir = base_dir / "data"
        # 允许测试或本地调试通过环境变量切换 Apifox mock 夹具目录。
        self.fixtures_dir = Path(
            os.getenv("AIDATAINSIGHT_FIXTURES_DIR", str(base_dir / "fixtures" / "apifox-mock"))
        )
        # 默认使用仓库内 SQLite，方便前后端联调时零配置启动。
        self.database_url = database_url or os.getenv(
            "AIDATAINSIGHT_DATABASE_URL",
            "sqlite:///" + str(self.data_dir / "dev.db"),
        )


@lru_cache
def get_settings() -> Settings:
    """缓存配置实例，避免每次依赖注入都重复解析路径和环境变量。"""

    return Settings()
