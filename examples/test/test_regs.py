from litex import RemoteClient

wb = RemoteClient()
wb.open()

# # #

fpga_id = ""
for i in range(256):
    c = chr(wb.read(wb.bases.identifier_mem + 4*i) & 0xff)
    fpga_id += c
    if c == "\0":
        break
print("fpga_id: " + fpga_id)
print("frequency: {}MHz".format(wb.constants.system_clock_frequency/1000000))
print("link up: {}".format(wb.regs.pcie_phy_lnk_up.read()))
print("bus_master_enable: {}".format(wb.regs.pcie_phy_bus_master_enable.read()))
print("msi_enable: {}".format(wb.regs.pcie_phy_msi_enable.read()))
print("max_req_request_size: {}".format(wb.regs.pcie_phy_max_request_size.read()))
print("max_payload_size: {}".format(wb.regs.pcie_phy_max_payload_size.read()))

# # #

wb.close()
