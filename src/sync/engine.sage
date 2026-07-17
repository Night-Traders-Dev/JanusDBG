## Synchronization engine for dual-core debug operations.
## Coordinates halt, resume, step, and breakpoint operations
## across multiple debug sessions (ARM + RISC-V).
from lib.log import debug, info, warn, error
from src.session.session import sm_get_adapter

## Create a new synchronization engine.
proc create_sync_engine(session_mgr, logger):
    return {
        "session_mgr": session_mgr,
        "logger": logger,
        "breakpoints": {}
    }

## Halt multiple sessions sequentially.
proc sync_halt(engine, session_names: Array):
    let sm = engine["session_mgr"]
    for name in session_names:
        let adapter = sm_get_adapter(sm, name)
        adapter.halt()

## Resume multiple sessions sequentially.
proc sync_resume(engine, session_names: Array):
    let sm = engine["session_mgr"]
    for name in session_names:
        let adapter = sm_get_adapter(sm, name)
        adapter.resume()

## Step multiple sessions sequentially.
proc sync_step(engine, session_names: Array):
    let sm = engine["session_mgr"]
    for name in session_names:
        let adapter = sm_get_adapter(sm, name)
        adapter.step()

## Set a breakpoint on multiple sessions at the same address.
## Tracks the breakpoint in the engine for later management.
proc sync_set_breakpoint(engine, session_names: Array, addr: String):
    let sm = engine["session_mgr"]
    engine["breakpoints"][addr] = session_names
    for name in session_names:
        let adapter = sm_get_adapter(sm, name)
        adapter.set_breakpoint(addr)

## Get merged state from multiple sessions.
## Returns a dict keyed by session name with raw adapter response strings.
proc sync_get_merged_state(engine, session_names: Array):
    let sm = engine["session_mgr"]
    let state = {}
    for name in session_names:
        let adapter = sm_get_adapter(sm, name)
        state[name] = adapter.read_registers()
    return state
