from __future__ import annotations

from collections.abc import Iterable, Sequence
import psycopg
from psycopg import sql

PROJECT_TABLES = (
    "crm_activities", "invoices", "inventory_movements", "sale_items", "sales",
    "purchase_items", "purchase_orders", "opportunities", "leads", "customers",
    "products", "categories", "suppliers", "employees",
)


def connect(url: str) -> psycopg.Connection:
    return psycopg.connect(url)


def assert_empty_or_reset(conn: psycopg.Connection, reset: bool) -> None:
    with conn.cursor() as cur:
        cur.execute("SELECT " + " + ".join(f"(SELECT count(*) FROM {t})" for t in PROJECT_TABLES))
        populated = cur.fetchone()[0]
        if populated and not reset:
            raise RuntimeError("Database has data. Refusing to append; rerun explicitly with --reset.")
        if reset:
            # TRUNCATE is transactional in PostgreSQL. Scope is limited to this project's tables.
            cur.execute(sql.SQL("TRUNCATE {} RESTART IDENTITY CASCADE").format(sql.SQL(", ").join(map(sql.Identifier, PROJECT_TABLES))))


def copy_rows(conn: psycopg.Connection, table: str, columns: Sequence[str], rows: Iterable[Sequence[object]]) -> None:
    statement = sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier(table), sql.SQL(", ").join(map(sql.Identifier, columns))
    )
    with conn.cursor() as cur, cur.copy(statement) as copy:
        for row in rows:
            copy.write_row(row)


def insert_returning(conn: psycopg.Connection, table: str, columns: Sequence[str], rows: list[Sequence[object]], key: str, batch_size: int) -> list[int]:
    ids: list[int] = []
    for start in range(0, len(rows), batch_size):
        batch = rows[start:start + batch_size]
        values = sql.SQL(", ").join(sql.SQL("({})").format(sql.SQL(", ").join([sql.Placeholder()] * len(columns))) for _ in batch)
        statement = sql.SQL("INSERT INTO {} ({}) VALUES {} RETURNING {}").format(
            sql.Identifier(table), sql.SQL(", ").join(map(sql.Identifier, columns)), values, sql.Identifier(key)
        )
        parameters = [item for row in batch for item in row]
        with conn.cursor() as cur:
            cur.execute(statement, parameters)
            ids.extend(row[0] for row in cur.fetchall())
    return ids
