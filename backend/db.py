"""
ReelGrab database — SQLite full schema for users, credits, jobs.
Free first video baked in.
"""
from sqlalchemy import create_engine, Column, String, Integer, DateTime, Boolean, Text, Float
from sqlalchemy.orm import sessionmaker, declarative_base
from datetime import datetime
import os
from pathlib import Path

DB_PATH = os.environ.get("REELGRAB_DB", str(Path(os.environ.get("REELGRAB_UPLOAD_DIR", "/tmp/reelgrab")) / "reelgrab.db"))
Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)

engine = create_engine(f"sqlite:///{DB_PATH}", connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    id = Column(String(64), primary_key=True)
    plan = Column(String(32), default="free")
    credits = Column(Integer, default=0)
    videos_used = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    stripe_customer_id = Column(String(128), nullable=True)
    email = Column(String(255), nullable=True)

class Job(Base):
    __tablename__ = "jobs"
    id = Column(String(64), primary_key=True)
    user_id = Column(String(64), index=True)
    status = Column(String(32), default="pending")
    motion = Column(String(32), default="kenburns")
    photos_count = Column(Integer, default=0)
    video_path = Column(String(512), nullable=True)
    error = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    finished_at = Column(DateTime, nullable=True)

class CreditLedger(Base):
    __tablename__ = "credit_ledger"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(64), index=True)
    delta = Column(Integer)
    reason = Column(String(128))
    balance_after = Column(Integer)
    created_at = Column(DateTime, default=datetime.utcnow)

class FreeGrant(Base):
    __tablename__ = "free_grants"
    ip_hash = Column(String(64), primary_key=True)
    free_used = Column(Integer, default=0)
    first_seen = Column(DateTime, default=datetime.utcnow)
    last_user_id = Column(String(64), nullable=True)
    used_at = Column(DateTime, nullable=True)

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_or_create_user(db, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        user = User(id=user_id, plan="free", credits=0, videos_used=0)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user

import hashlib as _hashlib

def _hash_key(ip: str, fp: str = "") -> str:
    salt = os.environ.get("REELGRAB_IP_SALT", "reelgrab-static-salt")
    raw = salt + "|" + (ip or "unknown") + "|" + (fp or "nofp")
    return _hashlib.sha256(raw.encode()).hexdigest()[:64]

def free_available_for_ip(db, ip: str, fp: str = "") -> bool:
    row = db.query(FreeGrant).filter(FreeGrant.ip_hash == _hash_key(ip, fp)).first()
    return (row is None) or (row.free_used == 0)

def consume_free_for_ip(db, ip: str, user_id: str, fp: str = "") -> bool:
    h = _hash_key(ip, fp)
    row = db.query(FreeGrant).filter(FreeGrant.ip_hash == h).first()
    if row is None:
        row = FreeGrant(ip_hash=h, free_used=1, last_user_id=user_id, used_at=datetime.utcnow())
        db.add(row)
        db.commit()
        return True
    if row.free_used == 0:
        row.free_used = 1
        row.last_user_id = user_id
        row.used_at = datetime.utcnow()
        db.commit()
        return True
    return False

def consume_credit(db, user_id: str, amount: int = 1) -> tuple:
    user = get_or_create_user(db, user_id)
    if user.plan == "pro":
        user.videos_used += amount
        db.commit()
        return True, user
    if user.credits < amount:
        return False, user
    user.credits -= amount
    user.videos_used += amount
    db.add(CreditLedger(user_id=user_id, delta=-amount, reason="generate", balance_after=user.credits))
    db.commit()
    db.refresh(user)
    return True, user

def add_credits(db, user_id: str, amount: int, reason: str) -> User:
    user = get_or_create_user(db, user_id)
    user.credits += amount
    if reason == "pro_upgrade":
        user.plan = "pro"
        user.credits = max(user.credits, 9999)
    db.add(CreditLedger(user_id=user_id, delta=amount, reason=reason, balance_after=user.credits))
    db.commit()
    db.refresh(user)
    return user
