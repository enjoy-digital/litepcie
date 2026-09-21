"""The receive tap must reconnect every bit, or stop before changing any net."""
from types import SimpleNamespace
import subprocess

import pytest

from litepcie.frontend.ptm.sniffer import S7PCIePTMSniffer


def make_phy(lanes=1, enabled=True, mode="Endpoint"):
    platform = SimpleNamespace(
        toolchain=SimpleNamespace(pre_optimize_commands=[]),
        add_source=lambda path: None,
    )
    return SimpleNamespace(platform=platform, nlanes=lanes, with_ptm=enabled, mode=mode)


@pytest.mark.parametrize("lanes", [2, 4, 8])
def test_rejects_striped_links(lanes):
    phy = make_phy(lanes=lanes)
    with pytest.raises(ValueError, match="x1"):
        S7PCIePTMSniffer(phy)
    assert not phy.platform.toolchain.pre_optimize_commands


@pytest.mark.parametrize("kwargs", [dict(enabled=False), dict(mode="RootPort")])
def test_rejects_incompatible_phy(kwargs):
    with pytest.raises(ValueError):
        S7PCIePTMSniffer(make_phy(**kwargs))


@pytest.mark.parametrize("missing", ["", "net", "pin"])
def test_tap_tcl_reconnects_or_fails_before_mutation(missing):
    phy = make_phy()
    S7PCIePTMSniffer(phy)
    commands = '\n'.join(command.format(build_name="endpoint")
                         for command in phy.platform.toolchain.pre_optimize_commands)
    # Exercise real Tcl parsing, including literal bus indices, and emulate the
    # small Vivado command surface used by the post-synthesis connection script.
    script = r'''
set changes 0
proc get_nets {args} {
    set name [lindex $args end]
    if {[lindex $args 0] eq "-of_objects"} {return placeholder}
    if {$::missing eq "net" && [string match {*\[15\]} $name]} {return {}}
    return [list $name]
}
proc get_pins {args} {
    set name [lindex $args end]
    if {$::missing eq "pin" && [string match {*\[15\]} $name]} {return {}}
    return [list $name]
}
proc disconnect_net {args} {incr ::changes}
proc connect_net {args} {incr ::changes}
'''
    script += f'set missing {{{missing}}}\n'
    script += 'set failed [catch {\n' + commands + '\n} message]\n'
    script += 'puts "$failed $changes"\nputs $message\n'
    result = subprocess.run(["tclsh"], input=script, text=True, capture_output=True, check=True)
    assert not result.stderr
    if missing:
        assert result.stdout.startswith("1 0\nPTM receive tap: missing " + missing)
    else:
        assert result.stdout.startswith("0 36\n")


@pytest.mark.parametrize("device", ["xc7a35tcsg324-2", "xc7k325tffg900-2"])
def test_standalone_generator_enables_ptm_configuration_and_tap(tmp_path, device):
    import json
    from pathlib import Path
    import sys

    config = {
        "phy": "S7PCIEPHY", "phy_device": device, "phy_lanes": 1,
        "phy_pcie_data_width": 64, "phy_data_width": 64, "phy_bar0_size": 0x40000,
        "clk_freq": 125000000, "clk_external": False,
        "dma_channels": 1, "msi_irqs": 1, "ptm": True,
    }
    config_path = tmp_path / "endpoint.yml"
    config_path.write_text(json.dumps(config))
    build = tmp_path / "build"
    result = subprocess.run([
        sys.executable, "-m", "litepcie.gen", str(config_path),
        "--output-dir", str(build), "--header-dir", str(tmp_path),
    ], cwd=Path(__file__).resolve().parents[1], text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    tcl = (build / "gateware/litepcie_core.tcl").read_text()
    rtl = (build / "gateware/litepcie_core.v").read_text()
    assert "CONFIG.EXT_PCI_CFG_Space {True}" in tcl
    assert "CONFIG.EXT_PCI_CFG_Space_Addr {6B}" in tcl
    assert "sniffer_tap pcie_ptm_sniffer_tap(" in rtl
    assert "pcie_ptm_sniffer_tap/rx_data_in[15]" in tcl
    assert "time_ns" in rtl
    assert "CSR_PTM_REQUESTER_CONTROL_ADDR" in (tmp_path / "csr.h").read_text()
