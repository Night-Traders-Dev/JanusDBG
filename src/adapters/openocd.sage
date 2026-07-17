## OpenOCD adapter for RISC-V debugging.
## Communicates via OpenOCD's Tcl server (port 6666 by default).
from tcp import connect as tcp_connect, sendall, recvline, close as tcp_close
from lib.log import debug, info, warn, error

class OpenOCDAdapter:
    ## Create a new OpenOCD adapter targeting the given host and port.
    proc init(self, host: String, port: Number, logger):
        self.host = host
        self.port = port
        self.logger = logger
        self.fd = -1

    ## Connect to the OpenOCD Tcl server.
    proc connect(self):
        info(self.logger, "OpenOCD connecting to " + self.host + ":" + str(self.port))
        self.fd = tcp_connect(self.host, self.port)
        if self.fd < 0:
            raise "Failed to connect to OpenOCD at " + self.host + ":" + str(self.port)
        info(self.logger, "OpenOCD connected")

    ## Disconnect from the OpenOCD Tcl server.
    proc disconnect(self):
        if self.fd >= 0:
            tcp_close(self.fd)
            self.fd = -1
            info(self.logger, "OpenOCD disconnected")

    ## Send a raw Tcl command and return the response.
    proc send_tcl(self, cmd: String):
        if self.fd < 0:
            raise "OpenOCD not connected"
        sendall(self.fd, cmd + "\n")
        let response = recvline(self.fd, 65536)
        if response == nil:
            return ""
        return response

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

    ## Start collecting trace data or performance counters.
    proc start_trace(self):
        info(self.logger, "Starting trace collection")
        return self.send_tcl("trace start")

    ## Stop trace collection.
    proc stop_trace(self):
        info(self.logger, "Stopping trace collection")
        return self.send_tcl("trace stop")

    ## Poll the accumulated trace data to feed into timeline/flamegraph builders.
    proc poll_trace(self):
        return self.send_tcl("trace status")
