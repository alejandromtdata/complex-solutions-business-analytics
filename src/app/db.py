from contextlib import contextmanager
import psycopg
from .config import settings

@contextmanager
def db():
    with psycopg.connect(settings.database_url) as conn:
        yield conn
