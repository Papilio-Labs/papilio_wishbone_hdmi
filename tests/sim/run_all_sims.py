#!/usr/bin/env python3
"""
Run all simulation tests for papilio_wishbone_hdmi.

Discovers all tb_*.v files in this directory and runs them with iverilog/vvp.
Uses papilio_dev_tools run_sim module for simulation infrastructure.

Usage:
    python run_all_sims.py

Requirements:
    - OSS CAD Suite (iverilog, vvp) on PATH or in standard install locations
    - papilio_dev_tools library present in workspace

Author: Papilio Labs
License: MIT
"""

import sys
import os
import glob
import subprocess
from pathlib import Path

# ---------------------------------------------------------------------------
# Locate papilio_dev_tools/scripts on the Python path
# ---------------------------------------------------------------------------
_this_dir   = Path(__file__).parent          # tests/sim/
_lib_root   = _this_dir.parent.parent        # papilio_wishbone_hdmi/
_dev_tools  = _lib_root.parent / "papilio_dev_tools" / "scripts"

sys.path.insert(0, str(_dev_tools))

try:
    import run_sim
except ImportError:
    print("Error: Could not import run_sim from papilio_dev_tools/scripts", file=sys.stderr)
    print(f"  Expected path: {_dev_tools}", file=sys.stderr)
    print("  Ensure papilio_dev_tools is present alongside this library.", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Gateware sources to include when compiling testbenches
# ---------------------------------------------------------------------------
GATEWARE_DIR = _lib_root / "gateware"

# Modules under test — add the DUT sources for each testbench
TESTBENCH_SOURCES = {
    "tb_wb_video_ctrl.v": [
        str(GATEWARE_DIR / "wb_video_ctrl.v"),
        str(GATEWARE_DIR / "video_top_wb.v"),   # may be in archive; stub if absent
        str(GATEWARE_DIR / "testpattern.v"),
    ],
    "tb_wb_char_ram.v": [
        str(GATEWARE_DIR / "wb_char_ram.v"),
        str(GATEWARE_DIR / "char_ram_8x8.v"),
        str(GATEWARE_DIR / "char_ram_dpb.v"),
    ],
}


def find_testbenches():
    """Find all testbench files (tb_*.v) in this directory."""
    return sorted(Path(_this_dir).glob("tb_*.v"))


def resolve_sources(testbench_name):
    """Return list of source files for a testbench, filtering out missing files."""
    sources = [str(_this_dir / testbench_name)]
    extra = TESTBENCH_SOURCES.get(testbench_name, [])
    for src in extra:
        if Path(src).exists():
            sources.append(src)
        else:
            # Check archive directory
            archive_path = GATEWARE_DIR / "archive" / Path(src).name
            if archive_path.exists():
                sources.append(str(archive_path))
            else:
                print(f"  Warning: source not found, skipping: {src}")
    return sources


def run_testbench(testbench: Path, oss_cad_path) -> bool:
    """Compile and run a single testbench."""
    print(f"\n{'='*60}")
    print(f"Running: {testbench.name}")
    print("=" * 60)

    sources = resolve_sources(testbench.name)
    output  = str(_this_dir / testbench.stem) + ".vvp"

    success = run_sim.compile_verilog(
        sources    = sources,
        output     = output,
        include_dirs = [str(GATEWARE_DIR)],
        standard   = "2012",
        oss_cad_path = oss_cad_path,
    )
    if not success:
        return False

    return run_sim.run_simulation(output, oss_cad_path=oss_cad_path)


def main():
    print("=" * 60)
    print("papilio_wishbone_hdmi — Simulation Test Runner")
    print("=" * 60)

    # Set up environment (finds OSS CAD Suite)
    oss_cad_path = run_sim.setup_environment()

    # Discover testbenches
    testbenches = find_testbenches()
    if not testbenches:
        print("No testbenches found (tb_*.v)")
        return 0

    print(f"\nFound {len(testbenches)} testbench(es):")
    for tb in testbenches:
        print(f"  - {tb.name}")

    # Run each testbench
    results = []
    for tb in testbenches:
        success = run_testbench(tb, oss_cad_path)
        results.append((tb.name, success))

    # Summary
    print(f"\n{'='*60}")
    print("Test Summary")
    print("=" * 60)

    passed = sum(1 for _, ok in results if ok)
    failed = len(results) - passed

    for name, ok in results:
        status = "[PASS]" if ok else "[FAIL]"
        print(f"  {status}: {name}")

    print(f"\nTotal: {len(results)} | Passed: {passed} | Failed: {failed}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
