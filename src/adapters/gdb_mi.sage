## GDB/MI adapter for ARM Cortex-A debugging.
## Communicates with GDB via TCP using the Machine Interface protocol.
from tcp import connect as tcp_connect, sendall, recvline, close as tcp_close
from lib.log import debug, info, warn, error

class GDBMIAdapter:
    ## Create a new GDB/MI adapter targeting the given host and port.
    proc init(self, host: String, port: Number, logger):
        self.host = host
        self.port = port
        self.logger = logger
        self.fd = -1

    ## Connect to the GDB MI target. Reads and discards any greeting.
    proc connect(self):
        info(self.logger, "GDB connecting to " + self.host + ":" + str(self.port))
        self.fd = tcp_connect(self.host, self.port)
        if self.fd < 0:
            raise "Failed to connect to GDB at " + self.host + ":" + str(self.port)
        info(self.logger, "GDB connected")

    ## Disconnect from the GDB MI target.
    proc disconnect(self):
        if self.fd >= 0:
            tcp_close(self.fd)
            self.fd = -1
            info(self.logger, "GDB disconnected")

    ## Send a raw MI command and return the response.
    ## Reads lines until the (gdb) prompt is found.
    proc send_command(self, cmd: String):
        if self.fd < 0:
            raise "GDB not connected"
        sendall(self.fd, cmd + "\n")
        let response = ""
        while true:
            let line = recvline(self.fd, 32768)
            if line == nil:
                break
            if line == "(gdb)\n" or line == "(gdb)":
                break
            response = response + line
        return response

    ## Halt the target.
    proc halt(self):
        return self.send_command("-exec-interrupt")

    ## Resume execution.
    proc cont(self):
        return self.send_command("-exec-continue")

    ## Single-step the target.
    proc step(self):
        return self.send_command("-exec-step")

    ## Insert a breakpoint at the given location.
    proc set_breakpoint(self, location: String):
        return self.send_command("-break-insert " + location)

    ## Read all target registers.
    proc read_registers(self):
        return self.send_command("-target-reg-list")
