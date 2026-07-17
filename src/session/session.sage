## Session manager for dual-core debug sessions.
## Implemented as a dictionary-based factory (avoids class patterns
## that some codegen backends can't handle).
from lib.log import debug, info, warn, error

## Create a new session manager.
proc create_session_manager(logger):
    return {
        "logger": logger,
        "sessions": {},
        "state": "disconnected"
    }

## Register a debug session by name and target address.
proc sm_register(sm, name: String, target: String):
    sm["sessions"][name] = {
        "name": name,
        "target": target,
        "connected": false,
        "state": nil
    }
    info(sm["logger"], "Registered session: " + name + " @ " + target)

## Connect to a named session.
proc sm_connect(sm, name: String):
    let sess = sm["sessions"][name]
    if sess == nil:
        raise "Unknown session: " + name
    info(sm["logger"], "Connecting " + name + " to " + sess["target"])
    sess["connected"] = true

## Disconnect from a named session.
proc sm_disconnect(sm, name: String):
    let entry = sm["sessions"][name]
    if entry != nil:
        entry["connected"] = false
        info(sm["logger"], "Disconnected " + name)

## Get all registered sessions and their status.
proc sm_get_sessions(sm):
    return sm["sessions"]
