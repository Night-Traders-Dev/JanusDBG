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

## Register a debug session by name, target address, and adapter type.
## adapter_type: "gdb_mi" for ARM/GDB, "openocd" for RISC-V/OpenOCD.
proc sm_register(sm, name: String, target: String, adapter_type: String):
    sm["sessions"][name] = {
        "name": name,
        "target": target,
        "adapter_type": adapter_type,
        "connected": false,
        "state": nil,
        "adapter": nil
    }
    info(sm["logger"], "Registered session: " + name + " @ " + target + " (" + adapter_type + ")")

## Connect to a named session, creating the appropriate adapter.
proc sm_connect(sm, name: String):
    let sess = sm["sessions"][name]
    if sess == nil:
        raise "Unknown session: " + name

    let parts = split(sess["target"], ":")
    let host = parts[0]
    let port = tonumber(parts[1])

    let adapter = nil
    if sess["adapter_type"] == "gdb_mi":
        from src.adapters.gdb_mi import GDBMIAdapter
        adapter = GDBMIAdapter(host, port, sm["logger"])
    elif sess["adapter_type"] == "openocd":
        from src.adapters.openocd import OpenOCDAdapter
        adapter = OpenOCDAdapter(host, port, sm["logger"])

    if adapter == nil:
        raise "Unknown adapter type: " + sess["adapter_type"]

    adapter.connect()
    sess["adapter"] = adapter
    sess["connected"] = true
    info(sm["logger"], "Connected " + name)

## Disconnect from a named session.
proc sm_disconnect(sm, name: String):
    let sess = sm["sessions"][name]
    if sess != nil:
        if sess["adapter"] != nil:
            sess["adapter"].disconnect()
            sess["adapter"] = nil
        sess["connected"] = false
        info(sm["logger"], "Disconnected " + name)

## Get the adapter for a named session.
proc sm_get_adapter(sm, name: String):
    let sess = sm["sessions"][name]
    if sess == nil:
        raise "Unknown session: " + name
    if sess["adapter"] == nil:
        raise "Session not connected: " + name
    return sess["adapter"]

## Get all registered sessions and their status.
proc sm_get_sessions(sm):
    return sm["sessions"]
