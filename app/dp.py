"""
Database utilities: creates a SQLAlchemy engine and session factory,
and provides a helper to run read queries cleanly.
"""

import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Load environment variables from .env (used in local/dev)
load_dotenv()

# DATABASE_URL is the single source of truth for where we connect
DATABASE_URL = os.getenv("DATABASE_URL", "")

# Create engine with pool_pre_ping to survive idle connections on cloud DBs
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

# Session factory; autocommit False so WE control transactions
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)

def fetch_all(db, sql: str, params: dict | None = None):
    """
    Execute a SELECT statement and return a list of mapping rows (dict-like).
    """
    return db.execute(text(sql), params or {}).mappings().all()