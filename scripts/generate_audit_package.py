import json
from pathlib import Path

ROOT = Path(".")
AUDIT = ROOT / "audit_package"
DEPLOY = ROOT / "deployments"
TREASURY = ROOT / "treasury"
CONSTITUTION = ROOT / "constitution"


def load_json(path):
    if path.exists():
        return json.loads(path.read_text())
    return None


def write_md(path, content):
    path.write_text(content)


def generate_protocol_overview():
    txt = """
# NEXUS Sovereign Financial System

NEXUS is a deterministic financial protocol designed for long-term stability.

Core architecture layers:

• Core protocol contracts  
• Sovereign multisig governance  
• Economic constitution invariants  
• Treasury receipt accounting  
• Macro stress risk engine  

All critical protocol actions are traceable through deterministic receipts and governance logs.
"""
    write_md(AUDIT / "protocol_overview.md", txt.strip())


def generate_contract_registry():
    gov = load_json(DEPLOY / "arbitrum-sepolia-governance-final.json")

    if gov is None:
        return

    data = {
        "network": gov["network"],
        "chainId": gov["chainId"],
        "coreContracts": gov["activeCore"],
    }

    (AUDIT / "contracts_registry.json").write_text(json.dumps(data, indent=2))


def generate_governance_topology():
    gov = load_json(DEPLOY / "arbitrum-sepolia-governance-final.json")

    if gov is None:
        return

    topo = gov["finalGovernanceTopology"]

    data = {
        "admin": topo["admin"],
        "adminType": topo["adminType"],
        "guardian": topo["guardian"],
        "keeper": topo["keeper"],
    }

    (AUDIT / "governance_topology.json").write_text(json.dumps(data, indent=2))


def generate_constitution_summary():
    inv = CONSTITUTION / "constitution_invariants.md"

    if not inv.exists():
        return

    txt = "# Economic Constitution\n\n"
    txt += inv.read_text()

    write_md(AUDIT / "constitution_summary.md", txt)


def generate_treasury_summary():
    txt = """
# Treasury Receipt System

The NEXUS treasury system records deterministic receipts for all critical
financial events.

Receipts include:

• mint
• burn
• liquidation
• treasury inflow
• treasury outflow
• governance action

Receipts are linked using hash chaining for auditability.
"""

    write_md(AUDIT / "treasury_receipts.md", txt.strip())


def main():

    AUDIT.mkdir(exist_ok=True)

    generate_protocol_overview()
    generate_contract_registry()
    generate_governance_topology()
    generate_constitution_summary()
    generate_treasury_summary()

    print("AUDIT PACKAGE GENERATED")


if __name__ == "__main__":
    main()
