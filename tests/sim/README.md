# Simulation Tests for papilio_wishbone_hdmi

This directory contains Verilog testbenches for the `papilio_wishbone_hdmi` library gateware modules.

## Testbenches

| File | DUT | Description |
|------|-----|-------------|
| `tb_wb_video_ctrl.v` | `wb_video_ctrl.v` | Wishbone video control register — reset, write/read pattern mode, version register |
| `tb_wb_char_ram.v` | `wb_char_ram.v` | Character RAM — cursor R/W, character write with auto-advance, line wrap, control register |

## Running Tests

**Requirements:** OSS CAD Suite (provides `iverilog` + `vvp`) or equivalent.

```bash
# Run all simulations
python run_all_sims.py
```

The runner uses `papilio_dev_tools/scripts/run_sim.py` for environment setup and compilation.

## Test Coverage

### tb_wb_video_ctrl

1. Reset: `wb_ack_o = 0` during reset, `pattern_mode` defaults to `0x03` (text mode)
2. Write pattern mode register (address `0x10`)
3. Read back pattern mode register
4. Write pattern `0x01` (grid)
5. Read version register (`0x11` → `0x02`)
6. Write to unused address — no side effect

### tb_wb_char_ram

1. Reset: `wb_ack_o = 0`
2. Default cursor at `(0, 0)`
3. Write cursor to `(5, 3)`, read back
4. Write attribute register (`0x23`)
5. Write character `'A'` → cursor auto-advances to `(6, 3)`
6. Write at column 79 → cursor wraps to `(0, 4)`
7. Control register write (clear screen trigger)

## Adding New Tests

1. Create `tb_<module_name>.v` following the testbench pattern above
2. Add DUT sources to `TESTBENCH_SOURCES` dict in `run_all_sims.py`
3. The runner discovers all `tb_*.v` files automatically

## VCD Output

Each testbench generates a `.vcd` waveform file (e.g., `tb_wb_video_ctrl.vcd`) that can be viewed in GTKWave.
