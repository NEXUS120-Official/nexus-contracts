import hashlib
import json
from dataclasses import dataclass, asdict
from typing import Optional


@dataclass
class TreasuryReceipt:
    receipt_type: str
    actor: str
    amount: str
    asset: str
    block_number: int
    tx_hash: str
    timestamp_utc: str
    prev_hash: str = ""

    def to_canonical_dict(self) -> dict:
        return {
            "receipt_type": self.receipt_type,
            "actor": self.actor,
            "amount": self.amount,
            "asset": self.asset,
            "block_number": self.block_number,
            "tx_hash": self.tx_hash,
            "timestamp_utc": self.timestamp_utc,
            "prev_hash": self.prev_hash,
        }

    def to_canonical_json(self) -> str:
        return json.dumps(
            self.to_canonical_dict(),
            sort_keys=True,
            separators=(",", ":")
        )

    def compute_receipt_hash(self) -> str:
        payload = self.to_canonical_json().encode("utf-8")
        return hashlib.sha256(payload).hexdigest()

    def to_receipt_record(self) -> dict:
        record = self.to_canonical_dict()
        record["receipt_hash"] = self.compute_receipt_hash()
        return record


def build_receipt(
    receipt_type: str,
    actor: str,
    amount: str,
    asset: str,
    block_number: int,
    tx_hash: str,
    timestamp_utc: str,
    prev_hash: str = "",
) -> dict:
    receipt = TreasuryReceipt(
        receipt_type=receipt_type,
        actor=actor,
        amount=amount,
        asset=asset,
        block_number=block_number,
        tx_hash=tx_hash,
        timestamp_utc=timestamp_utc,
        prev_hash=prev_hash,
    )
    return receipt.to_receipt_record()


if __name__ == "__main__":
    example = build_receipt(
        receipt_type="mint",
        actor="VaultManager",
        amount="5000",
        asset="NXUSD",
        block_number=248552823,
        tx_hash="0xexample",
        timestamp_utc="2026-03-09T22:20:00Z",
        prev_hash="",
    )
    print(json.dumps(example, indent=2))
