"""Reproducible technology-independent Yosys synthesis (no device claims)."""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]


def summarize(netlist_path: Path) -> dict:
    module = json.loads(netlist_path.read_text())["modules"]["dual_async_fifo"]
    cells = module["cells"]
    counts = Counter(c["type"] for c in cells.values())
    ff_bits = 0
    memories = []
    latches = []
    for name, cell in cells.items():
        kind = cell["type"].lower()
        if "latch" in kind:
            latches.append(name)
        if "dff" in kind or "dffe" in kind:
            ff_bits += len(cell["connections"].get("Q", []))
        if cell["type"] == "$mem_v2":
            params = cell["parameters"]
            width, depth = int(params["WIDTH"], 2), int(params["SIZE"], 2)
            memories.append({"name": name, "width": width, "depth": depth, "bits": width * depth})
    if latches:
        raise RuntimeError(f"Unexpected inferred latches: {latches}")
    metadata = counts.get("$scopeinfo", 0)
    return {"cells": len(cells)-metadata, "cells_including_metadata": len(cells), "metadata_cells": metadata,
            "cell_types": dict(sorted(counts.items())), "register_bits": ff_bits,
            "abstract_memories": memories, "memory_bits": sum(m["bits"] for m in memories),
            "inferred_latches": len(latches)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--packages", type=Path, default=Path("D:/fifo_tools/python"))
    ap.add_argument("--build-root", type=Path, default=Path("D:/fifo_build"))
    args = ap.parse_args()
    if not str(args.build_root.resolve()).isascii():
        raise SystemExit("Use an ASCII-only build path")
    output = REPO / "reports/synthesis"
    output.mkdir(parents=True, exist_ok=True)
    files = [x.strip() for x in (REPO / "sim/dual_rtl.f").read_text().splitlines() if x.strip()]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(args.packages.resolve())
    entry = "import sys,yowasp_yosys;sys.argv[0]='yowasp-yosys';sys.exit(yowasp_yosys._run_yosys_argv())"
    prefix = [sys.executable, "-c", entry]
    version = subprocess.check_output(prefix + ["-V"], env=env, text=True).strip()
    results = {"tool": version, "scope": "technology-independent, no liberty/device/PPA mapping",
               "ram_policy": "preserved abstract RAM first; separate fully generic FF/mux mapping",
               "source_sha256_lf": {name: hashlib.sha256((REPO / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
                                    for name in files}, "configurations": []}
    for stages in (2, 3):
        build = args.build_root / f"generic_s{stages}"
        (build / "rtl").mkdir(parents=True, exist_ok=True)
        for name in files:
            shutil.copyfile(REPO / name, build / name)
        script = "\n".join([
            "read_verilog " + " ".join(files),
            f"chparam -set SYNC_STAGES {stages} -set AUTO_REFRESH_CYCLES 32 dual_async_fifo",
            "synth -top dual_async_fifo -flatten -noabc -run begin:fine",
            "check -assert",
            "tee -o coarse_stat.json stat -json",
            "write_json coarse_netlist.json",
            "synth -top dual_async_fifo -noabc -run fine:check",
            "check -assert",
            "tee -o mapped_stat.json stat -json",
            "write_json mapped_netlist.json", ""])
        (build / "synth.ys").write_text(script, encoding="ascii")
        with (build / "driver.log").open("w", encoding="utf-8") as log:
            proc = subprocess.run(prefix + ["-T", "-l", "synthesis.log", "-s", "synth.ys"],
                                  cwd=build, env=env, stdout=log, stderr=subprocess.STDOUT)
        if proc.returncode:
            raise RuntimeError(f"Yosys failed: {build / 'driver.log'}")
        coarse = summarize(build / "coarse_netlist.json")
        mapped = summarize(build / "mapped_netlist.json")
        if len(coarse["abstract_memories"]) != 2 or coarse["memory_bits"] != 16384:
            raise RuntimeError("Expected two independent 256x32 abstract memories")
        if mapped["abstract_memories"]:
            raise RuntimeError("Generic mapping unexpectedly retained memories")
        result = {"sync_stages": stages, "coarse": coarse, "generic_mapped": mapped}
        results["configurations"].append(result)
        for name in ("synth.ys", "coarse_stat.json", "mapped_stat.json", "synthesis.log"):
            shutil.copyfile(build / name, output / f"s{stages}_{name}")
        print(f"SYNTHESIS: PASS stages={stages} abstract_ram_bits={coarse['memory_bits']} "
              f"logic_register_bits={coarse['register_bits']} generic_register_bits={mapped['register_bits']}", flush=True)
    (output / "summary.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
