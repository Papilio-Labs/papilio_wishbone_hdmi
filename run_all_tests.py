#!/usr/bin/env python3
"""
Top-level test runner for papilio_wishbone_hdmi.

Runs all simulation tests. Hardware tests (if configured) can be added
to tests/hw/ following the papilio_dev_tools pattern.

Usage:
    python run_all_tests.py           # run all tests
    python run_all_tests.py --sim-only

Author: Papilio Labs
License: MIT
"""

import sys
import subprocess
from pathlib import Path

lib_root  = Path(__file__).parent
sim_runner = lib_root / "tests" / "sim" / "run_all_sims.py"

def run_sim_tests():
    print("=" * 60)
    print("Running Simulation Tests")
    print("=" * 60)
    result = subprocess.run(
        [sys.executable, str(sim_runner)],
        cwd=str(lib_root / "tests" / "sim")
    )
    return result.returncode


if __name__ == "__main__":
    args = sys.argv[1:]
    exit_code = 0

    sim_only = "--sim-only" in args
    hw_only  = "--hw-only"  in args

    if not hw_only:
        exit_code |= run_sim_tests()

    if hw_only:
        print("No hardware tests configured yet.")
        print("See tests/hw/ (when added) for hardware test instructions.")

    sys.exit(exit_code)
