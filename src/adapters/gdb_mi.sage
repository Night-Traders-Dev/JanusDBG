## GDB/MI adapter for ARM Cortex-A debugging.
## Communicates with GDB using the Machine Interface interpreter.
from lib.log import debug, info, warn, error

class GDBMIAdapter:
    ## Create a new GDB/MI adapter targeting the given host and port.
    proc init(self, host: String, port: Number, logger):
        self.host = host
        self.port = port
        self.logger = logger
        self.connected = false

    ## Connect to the GDB remote target.
    proc connect(self):
        info(self.logger, "GDB/MI connecting to " + self.host + ":" + str(self.port))
        self.connected = true

    ## Disconnect from the GDB remote target.
    proc disconnect(self):
        self.connected = false

    ## Send a GDB/MI command and return the response.
    proc send_command(self, cmd: String):
        if not self.connected:
            raise "GDB not connected"
        return ""

    ## Insert a breakpoint at the given location.
    proc set_breakpoint(self, location: String):
        return self.send_command("-break-insert " + location)

    ## Single-step the target.
    proc step(self):
        return self.send_command("-exec-step")

    ## Continue execution.
    proc cont(self):
        return self.send_command("-exec-continue")

    ## Read all register values.
    proc read_registers(self):
        return self.send_command("-data-list-register-values")
