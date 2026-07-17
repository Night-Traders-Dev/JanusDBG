## Session manager for dual-core debug sessions.
from lib.log import debug, info, warn, error

class SessionManager:
    ## Create a new session manager with the given logger.
    proc init(self, logger):
        self.logger = logger
        self.sessions = {}
        self.state = "disconnected"

    ## Register a debug session by name and target address.
    proc register_session(self, name: String, target: String):
        self.sessions[name] = {
            "name": name,
            "target": target,
            "connected": false,
            "state": nil
        }
        info(self.logger, "Registered session: " + name + " @ " + target)

    ## Connect to a named session.
    proc connect(self, name: String):
        let sess = self.sessions[name]
        if sess == nil:
            raise "Unknown session: " + name
        info(self.logger, "Connecting " + name + " to " + sess["target"])
        sess["connected"] = true

    ## Disconnect from a named session.
    proc disconnect(self, name: String):
        let entry = self.sessions[name]
        if entry != nil:
            entry["connected"] = false
            info(self.logger, "Disconnected " + name)

    ## Get the current state of the session manager.
    proc get_state(self):
        return self.state

    ## Get all registered sessions and their status.
    proc get_sessions(self):
        return self.sessions
