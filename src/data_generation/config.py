from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import os


@dataclass(frozen=True)
class Settings:
    seed: int = 42
    start_date: date = date(2020, 1, 1)
    end_date: date = date(2026, 12, 31)
    scale: str = "small"
    batch_size: int = 1_000
    database_url: str = "postgresql://complex_admin:change_this_local_password@localhost:5433/complex_solutions"

    def __post_init__(self) -> None:
        if self.scale not in {"small", "full"} or self.end_date < self.start_date:
            raise ValueError("Invalid SCALE or date range")

    @classmethod
    def from_env(cls, scale: str | None = None) -> "Settings":
        def value(name: str, default: str) -> str:
            return os.getenv(name, default)
        database_url = value(
            "DATABASE_URL",
            f"postgresql://{value('POSTGRES_USER', 'complex_admin')}:{value('POSTGRES_PASSWORD', 'change_this_local_password')}@"
            f"{value('POSTGRES_HOST', 'localhost')}:{value('POSTGRES_PORT', '5433')}/{value('POSTGRES_DB', 'complex_solutions')}",
        )
        result = cls(
            seed=int(value("SEED", "42")),
            start_date=date.fromisoformat(value("START_DATE", "2020-01-01")),
            end_date=date.fromisoformat(value("END_DATE", "2026-12-31")),
            scale=scale or value("SCALE", "small"),
            batch_size=int(value("INSERT_BATCH_SIZE", "1000")),
            database_url=database_url,
        )
        return result


SCALE_TARGETS = {
    "small": {"employees": 14, "suppliers": 24, "products": 120, "customers": 360, "sales": 2_100, "leads": 520},
    "full": {"employees": 36, "suppliers": 72, "products": 3_600, "customers": 12_000, "sales": 220_000, "leads": 32_000},
}
