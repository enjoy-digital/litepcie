from litex.gen import *

from litepcie.common import *


class SlaveInternalPort:
    def __init__(self, data_width, address_decoder=None):
        self.address_decoder = address_decoder
        self.sink = Sink(completion_layout(data_width))
        self.source = Source(request_layout(data_width))


class MasterInternalPort:
    def __init__(self, data_width, channel=None, write_only=False, read_only=False):
        self.channel = channel
        self.write_only = write_only
        self.read_only = read_only
        self.sink = Sink(request_layout(data_width))
        self.source = Source(completion_layout(data_width))


class SlavePort:
    def __init__(self, port):
        self.address_decoder = port.address_decoder
        self.sink = port.source
        self.source = port.sink


class MasterPort:
    def __init__(self, port):
        self.channel = port.channel
        self.sink = port.source
        self.source = port.sink
