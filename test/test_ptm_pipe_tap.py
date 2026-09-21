# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
from types import SimpleNamespace
import subprocess
import pytest
from migen import Signal
from litepcie.frontend.ptm.pipe import S7PCIePTMMultiLaneSniffer, USPPCIePTMGen2Sniffer


@pytest.mark.parametrize('family,lanes', [('s7', 2), ('s7', 4), ('s7', 8), ('usp', 1), ('usp', 8)])
@pytest.mark.parametrize('missing', ['', 'source', 'target'])
def test_wide_tap_checks_all_connections_before_mutation(family, lanes, missing):
    platform = SimpleNamespace(toolchain=SimpleNamespace(pre_optimize_commands=[]), add_source=lambda _: None)
    phy = SimpleNamespace(platform=platform, with_ptm=True, mode='Endpoint', nlanes=lanes, speed='gen2')
    if family == 's7':
        phy.pcie_phy_params = {'o_pl_sel_lnk_width': Signal(2), 'o_pl_ltssm_state': Signal(6), 'o_user_lnk_up': Signal()}
        S7PCIePTMMultiLaneSniffer(phy)
        changes = 2*18*lanes
    else:
        phy.pcie_usp_phy_params = {'o_cfg_negotiated_width': Signal(3), 'o_cfg_ltssm_state': Signal(6), 'o_user_lnk_up': Signal()}
        USPPCIePTMGen2Sniffer(phy)
        changes = 2*(19*lanes+2)
    commands = '\n'.join(command.format(build_name='endpoint') for command in platform.toolchain.pre_optimize_commands)
    if family == 's7':
        # Vendor buses reserve 32 data and 4 K bits per lane.
        assert f'gt_rx_data_wire_filter[{32*(lanes-1)+15}]' in commands
        assert f'gt_rx_data_k_wire_filter[{4*(lanes-1)+1}]' in commands
    script = '''
set changes 0
proc get_cells {args} {return hard}
proc get_property {args} {return 1}
proc set_property {args} {}
proc get_pins {args} {
    set name [lindex $args end]
    if {$::missing eq "target" && [string match {*rx_data_in*} $name]} {return {}}
    return [list $name]
}
proc get_nets {args} {
    set name [lindex $args end]
    if {$::missing eq "source" && ([string match {*gt_rx_data_wire*} $name] || [string match {*PIPERX*DATA*} $name])} {return {}}
    return [list $name]
}
proc disconnect_net {args} {incr ::changes}
proc connect_net {args} {incr ::changes}
'''
    script += f'set missing {{{missing}}}\n'
    script += 'set failed [catch {\n'+commands+'\n} message]\nputs "$failed $changes"\nputs $message\n'
    result = subprocess.run(['tclsh'], input=script, text=True, capture_output=True, check=True)
    assert not result.stderr
    assert result.stdout.startswith('1 0\nPTM PIPE tap: missing' if missing else f'0 {changes}\n')
