from functools import lru_cache
from pathlib import Path
from typing import Optional
import os


class Settings:
    def __init__(self, database_url: Optional[str] = None) -> None:
        base_dir = Path(__file__).resolve().parents[1]
        self.base_dir = base_dir
        self.data_dir = base_dir / "data"
        self.fixtures_dir = Path(
            os.getenv("AIDATAINSIGHT_FIXTURES_DIR", str(base_dir / "fixtures" / "apifox-mock"))
        )
        self.database_url = database_url or os.getenv(
            "AIDATAINSIGHT_DATABASE_URL",
            "sqlite:///" + str(self.data_dir / "dev.db"),
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
