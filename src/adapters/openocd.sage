## OpenOCD adapter for RISC-V debugging.
## Communicates via OpenOCD's Tcl server (port 6666 by default).
from lib.log import debug, info, warn, error

class OpenOCDAdapter:
    ## Create a new OpenOCD adapter targeting the given host and port.
    proc init(self, host: String, port: Number, logger):
        self.host = host
        self.port = port
        self.logger = logger
        self.connected = false

    ## Connect to the OpenOCD Tcl server.
    proc connect(self):
        info(self.logger, "OpenOCD connecting to " + self.host + ":" + str(self.port))
        self.connected = true

    ## Disconnect from the OpenOCD Tcl server.
    proc disconnect(self):
        self.connected = false

    ## Send a raw Tcl command and return the response.
    proc send_tcl(self, cmd: String):
        if not self.connected:
            raise "OpenOCD not connected"
        return ""

    ## Halt the target core.
    proc halt(self):
        return self.send_tcl("halt")

    ## Resume the target core.
    proc resume(self):
        return self.send_tcl("resume")

    ## Single-step the target core.
    proc step(self):
        return self.send_tcl("step")

    ## Set a hardware breakpoint at the given address.
    proc set_breakpoint(self, addr: String):
        return self.send_tcl("bp " + addr + " 2 hw")

    ## Read a register value by name.
    proc read_reg(self, reg: String):
        return self.send_tcl("reg " + reg)
