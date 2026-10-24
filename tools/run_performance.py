"""Measure RTL latency/throughput, never infer a physical maximum clock rate."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--simulator-bin", type=Path, default=Path("D:/altera/14.1/modelsim_ase/win32aloem"))
    ap.add_argument("--build-root", type=Path, default=Path("D:/fifo_build"))
    ap.add_argument("--quick", action="store_true")
    args = ap.parse_args()
    out = REPO / "reports/performance"
    out.mkdir(parents=True, exist_ok=True)
    files = [s.strip() for s in (REPO / "sim/dual_rtl.f").read_text().splitlines() if s.strip()]
    files += ["tb/fifo_channel_checker.sv", "tb/fifo_performance_tb.sv"]
    cases = [(s, block, periods) for periods in ((10000,6000,17500,5000),(5000,23000,7000,25000))
             for block in ((0,8) if periods[0] == 10000 else (0,)) for s in (2,3)]
    if args.quick:
        cases = cases[:1]
    results = []
    for stages, block, periods in cases:
        name = f"perf_s{stages}_block{block}_aw{periods[0]}_ar{periods[1]}_bw{periods[2]}_br{periods[3]}"
        build = args.build_root / name
        (build / "rtl").mkdir(parents=True, exist_ok=True)
        (build / "tb").mkdir(exist_ok=True)
        for file in files:
            shutil.copyfile(REPO / file, build / file)

        def run(tool, argv, log):
            with (build / log).open("w", encoding="utf-8") as f:
                p = subprocess.run([str(args.simulator_bin / (tool + ".exe")), *argv], cwd=build,
                                   stdout=f, stderr=subprocess.STDOUT)
            if p.returncode:
                raise RuntimeError(f"{tool} failed; see {build / log}")

        if not (build / "modelsim.ini").exists(): run("vmap", ["-c"], "map.log")
        if not (build / "work").exists(): run("vlib", ["work"], "lib.log")
        run("vlog", ["-work", "work", *files[:-2]], "rtl.log")
        run("vlog", ["-sv", "-work", "work", *files[-2:]], "tb.log")
        params = [f"-gSYNC_STAGES={stages}", f"-gBLOCK_CYCLES={block}"]
        params += [f"-g{k}={v}" for k,v in zip(("A_WRITE_HALF_PS","A_READ_HALF_PS","B_WRITE_HALF_PS","B_READ_HALF_PS"),periods)]
        run("vsim", ["-c", "-onfinish", "stop", "-l", "run.log", *params, "work.fifo_performance_tb",
                      "-do", "run -all; quit -f"], "driver.log")
        text = (build / "run.log").read_text(encoding="utf-8")
        if "RESULT: PASS" not in text or re.search(r"CHECK_FAIL|RESULT: FAIL|TIMEOUT|\*\* (Error|Fatal):", text):
            raise RuntimeError(f"Performance self-check failed: {build / 'run.log'}")
        rows = []
        for ch in (0,1):
            def value(kind, key):
                m = re.search(rf"{kind}: channel={ch} [^\n]*\b{key}=([\d.]+)",text)
                if not m: raise RuntimeError(f"Missing benchmark field {ch}/{key}")
                return float(m[1])
            rows.append({"channel":ch,"first_read_ns":value("PERF_LATENCY","first_read_ns"),
                         "full_release_ns":value("PERF_LATENCY","full_release_ns"),
                         "window_ns":value("PERF_WINDOW","duration_ns"),"window_reads":int(value("PERF_WINDOW","reads")),
                         "words_per_s":value("PERF_WINDOW","words_per_s"),"mbps":value("PERF_WINDOW","mbps"),
                         "stall_cycles":int(value("PERF_WINDOW","stall_cycles"))})
        results.append({"name":name,"sync_stages":stages,"blocked_cycles_per_10":block,
                        "half_periods_ps":periods,"measurements":rows})
        shutil.copyfile(build / "run.log",out / (name+".log"))
        print("PERFORMANCE: PASS",name,rows,flush=True)
    (out / "summary.json").write_text(json.dumps({"scope":"RTL simulation, 200 us steady-state observation window",
                                                 "cases":results}, indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__":
    main()
