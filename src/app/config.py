from dataclasses import dataclass
import os
from dotenv import load_dotenv

load_dotenv()

@dataclass(frozen=True)
class AppSettings:
    database_url: str = os.getenv("DATABASE_URL", "postgresql://complex_admin:change_this_local_password@localhost:5433/complex_solutions")

settings = AppSettings()
