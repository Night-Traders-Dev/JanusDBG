## Test runner for JanusDBG.
from std.testing import create_suite, add_test, run, report, assert_equal, assert_not_equal, assert_true

let suite = create_suite("JanusDBG Tests")

## --- lib.log tests ---

proc test_log_create():
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    assert_not_equal(logger, nil, "logger should not be nil")
    assert_equal(logger["name"], "test", "logger name should match")
    assert_equal(logger["level"], 1, "logger level should match")

add_test(suite, "log: create_logger", test_log_create)

proc test_log_levels():
    from lib.log import create_logger, debug, info, warn, error, fatal
    let logger = create_logger("test", 0)
    assert_equal(logger["level"], 0, "debug level should be 0")

    let logger2 = create_logger("test", 4)
    assert_equal(logger2["level"], 4, "fatal level should be 4")

add_test(suite, "log: level constants", test_log_levels)

proc test_log_no_crash():
    from lib.log import create_logger, debug, info, warn, error, fatal
    let logger = create_logger("test", 1)
    info(logger, "info test")
    warn(logger, "warn test")
    error(logger, "error test")
    fatal(logger, "fatal test")
    debug(logger, "debug test (should be suppressed)")
    assert_true(true, "logger functions should not crash")

add_test(suite, "log: all functions no crash", test_log_no_crash)

## --- session manager tests ---

proc test_session_create():
    from lib.log import create_logger
    from src.session.session import create_session_manager
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    assert_not_equal(sm, nil, "session manager should not be nil")
    assert_equal(sm["state"], "disconnected", "initial state should be disconnected")

add_test(suite, "session: create", test_session_create)

proc test_session_register():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_get_sessions
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:2331", "gdb_mi")
    let sessions = sm_get_sessions(sm)
    assert_true(dict_has(sessions, "arm"), "arm session should exist")
    let arm = sessions["arm"]
    assert_equal(arm["target"], "localhost:2331", "target should match")
    assert_equal(arm["adapter_type"], "gdb_mi", "adapter type should match")
    assert_equal(arm["connected"], false, "should start disconnected")

add_test(suite, "session: register", test_session_register)

proc test_session_multiple():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_get_sessions
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "host1:2331", "gdb_mi")
    sm_register(sm, "rv", "host2:3333", "openocd")
    let sessions = sm_get_sessions(sm)
    assert_equal(len(sessions), 2, "should have 2 sessions")

add_test(suite, "session: register multiple", test_session_multiple)

proc test_session_connect_attempt():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_connect
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let caught = false
    try:
        sm_connect(sm, "arm")
    catch e:
        caught = true
    assert_true(caught, "connect should fail without GDB target")

add_test(suite, "session: connect attempt fails", test_session_connect_attempt)

proc test_session_disconnect_cleanup():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_disconnect, sm_get_sessions
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    sm_disconnect(sm, "arm")
    let arm = sm_get_sessions(sm)["arm"]
    assert_equal(arm["connected"], false, "should stay disconnected")
    assert_equal(arm["adapter"], nil, "adapter should be nil")

add_test(suite, "session: disconnect no-op when not connected", test_session_disconnect_cleanup)

proc test_session_get_adapter_unknown():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_get_adapter
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let caught = false
    try:
        sm_get_adapter(sm, "nonexistent")
    catch e:
        caught = true
    assert_true(caught, "get_adapter should raise for unknown session")

add_test(suite, "session: get_adapter unknown session", test_session_get_adapter_unknown)

proc test_session_get_adapter_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_get_adapter
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let caught = false
    try:
        sm_get_adapter(sm, "arm")
    catch e:
        caught = true
    assert_true(caught, "get_adapter should raise when not connected")

add_test(suite, "session: get_adapter not connected", test_session_get_adapter_not_connected)

## --- GDB/MI adapter tests ---

proc test_gdb_create():
    from lib.log import create_logger
    from src.adapters.gdb_mi import GDBMIAdapter
    let logger = create_logger("test", 1)
    let gdb = GDBMIAdapter("localhost", 2331, logger)
    assert_not_equal(gdb, nil, "adapter should not be nil")
    assert_equal(gdb.fd, -1, "fd should start at -1")

add_test(suite, "gdb_mi: create", test_gdb_create)

proc test_gdb_methods_raise_not_connected():
    from lib.log import create_logger
    from src.adapters.gdb_mi import GDBMIAdapter
    let logger = create_logger("test", 1)
    let gdb = GDBMIAdapter("localhost", 2331, logger)

    let halt_ok = false
    try:
        gdb.halt()
    catch e:
        if e == "GDB not connected":
            halt_ok = true
    assert_true(halt_ok, "halt should raise 'GDB not connected'")

    let cont_ok = false
    try:
        gdb.cont()
    catch e:
        if e == "GDB not connected":
            cont_ok = true
    assert_true(cont_ok, "cont should raise 'GDB not connected'")

    let step_ok = false
    try:
        gdb.step()
    catch e:
        if e == "GDB not connected":
            step_ok = true
    assert_true(step_ok, "step should raise 'GDB not connected'")

    let bp_ok = false
    try:
        gdb.set_breakpoint("*0x8000")
    catch e:
        if e == "GDB not connected":
            bp_ok = true
    assert_true(bp_ok, "set_breakpoint should raise 'GDB not connected'")

    let reg_ok = false
    try:
        gdb.read_registers()
    catch e:
        if e == "GDB not connected":
            reg_ok = true
    assert_true(reg_ok, "read_registers should raise 'GDB not connected'")

add_test(suite, "gdb_mi: methods raise when not connected", test_gdb_methods_raise_not_connected)

## --- OpenOCD adapter tests ---

proc test_ocd_create():
    from lib.log import create_logger
    from src.adapters.openocd import OpenOCDAdapter
    let logger = create_logger("test", 1)
    let ocd = OpenOCDAdapter("localhost", 3333, logger)
    assert_not_equal(ocd, nil, "adapter should not be nil")
    assert_equal(ocd.fd, -1, "fd should start at -1")

add_test(suite, "openocd: create", test_ocd_create)

proc test_ocd_methods_raise_not_connected():
    from lib.log import create_logger
    from src.adapters.openocd import OpenOCDAdapter
    let logger = create_logger("test", 1)
    let ocd = OpenOCDAdapter("localhost", 3333, logger)

    let halt_ok = false
    try:
        ocd.halt()
    catch e:
        if e == "OpenOCD not connected":
            halt_ok = true
    assert_true(halt_ok, "halt should raise 'OpenOCD not connected'")

    let resume_ok = false
    try:
        ocd.resume()
    catch e:
        if e == "OpenOCD not connected":
            resume_ok = true
    assert_true(resume_ok, "resume should raise 'OpenOCD not connected'")

    let step_ok = false
    try:
        ocd.step()
    catch e:
        if e == "OpenOCD not connected":
            step_ok = true
    assert_true(step_ok, "step should raise 'OpenOCD not connected'")

    let bp_ok = false
    try:
        ocd.set_breakpoint("0x80000000")
    catch e:
        if e == "OpenOCD not connected":
            bp_ok = true
    assert_true(bp_ok, "set_breakpoint should raise 'OpenOCD not connected'")

    let reg_ok = false
    try:
        ocd.read_reg("pc")
    catch e:
        if e == "OpenOCD not connected":
            reg_ok = true
    assert_true(reg_ok, "read_reg should raise 'OpenOCD not connected'")

add_test(suite, "openocd: methods raise when not connected", test_ocd_methods_raise_not_connected)

## --- RPC server tests ---

proc test_rpc_request():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:2331", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "getSessions", "id": 1}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_equal(resp["jsonrpc"], "2.0", "response should be jsonrpc 2.0")

add_test(suite, "rpc: basic request", test_rpc_request)

proc test_rpc_unknown_method():
    from lib.log import create_logger
    from src.session.session import create_session_manager
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "unknownMethod", "id": 3}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_equal(resp["error"]["code"], -32601, "should return method not found error")

add_test(suite, "rpc: unknown method", test_rpc_unknown_method)

proc test_rpc_halt_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "halt", "params": {"session": "arm"}, "id": 1}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "halt without connect should return error")
    assert_equal(resp["error"]["code"], -32000, "error code should be -32000")

add_test(suite, "rpc: halt without connect", test_rpc_halt_not_connected)

proc test_rpc_resume_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "resume", "params": {"session": "arm"}, "id": 2}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "resume without connect should return error")

add_test(suite, "rpc: resume without connect", test_rpc_resume_not_connected)

proc test_rpc_step_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "step", "params": {"session": "arm"}, "id": 3}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "step without connect should return error")

add_test(suite, "rpc: step without connect", test_rpc_step_not_connected)

proc test_rpc_set_breakpoint_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "setBreakpoint", "params": {"session": "arm", "addr": "*0x8000"}, "id": 4}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "setBreakpoint without connect should return error")

add_test(suite, "rpc: setBreakpoint without connect", test_rpc_set_breakpoint_not_connected)

proc test_rpc_read_registers_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "readRegisters", "params": {"session": "arm"}, "id": 5}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "readRegisters without connect should return error")

add_test(suite, "rpc: readRegisters without connect", test_rpc_read_registers_not_connected)

## --- sync engine tests ---

proc test_sync_engine_create():
    from lib.log import create_logger
    from src.session.session import create_session_manager
    from src.sync.engine import create_sync_engine
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    let engine = create_sync_engine(sm, logger)
    assert_not_equal(engine, nil, "sync engine should not be nil")
    assert_equal(engine["breakpoints"], {}, "breakpoints should start empty")

add_test(suite, "sync: create engine", test_sync_engine_create)

proc test_sync_halt_raises_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_halt
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let engine = create_sync_engine(sm, logger)
    let caught = false
    try:
        sync_halt(engine, ["arm"])
    catch e:
        caught = true
    assert_true(caught, "sync_halt should raise when not connected")

add_test(suite, "sync: halt raises when not connected", test_sync_halt_raises_not_connected)

proc test_sync_resume_raises_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_resume
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let engine = create_sync_engine(sm, logger)
    let caught = false
    try:
        sync_resume(engine, ["arm"])
    catch e:
        caught = true
    assert_true(caught, "sync_resume should raise when not connected")

add_test(suite, "sync: resume raises when not connected", test_sync_resume_raises_not_connected)

proc test_sync_step_raises_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_step
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let engine = create_sync_engine(sm, logger)
    let caught = false
    try:
        sync_step(engine, ["arm"])
    catch e:
        caught = true
    assert_true(caught, "sync_step should raise when not connected")

add_test(suite, "sync: step raises when not connected", test_sync_step_raises_not_connected)

proc test_sync_set_breakpoint_raises_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_set_breakpoint
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let engine = create_sync_engine(sm, logger)
    let caught = false
    try:
        sync_set_breakpoint(engine, ["arm"], "0x8000")
    catch e:
        caught = true
    assert_true(caught, "sync_set_breakpoint should raise when not connected")

add_test(suite, "sync: setBreakpoint raises when not connected", test_sync_set_breakpoint_raises_not_connected)

proc test_sync_get_merged_state_raises_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_get_merged_state
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let engine = create_sync_engine(sm, logger)
    let caught = false
    try:
        sync_get_merged_state(engine, ["arm"])
    catch e:
        caught = true
    assert_true(caught, "sync_get_merged_state should raise when not connected")

add_test(suite, "sync: getMergedState raises when not connected", test_sync_get_merged_state_raises_not_connected)

proc test_sync_multiple_sessions_fails():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_halt
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    sm_register(sm, "rv", "localhost:2", "openocd")
    let engine = create_sync_engine(sm, logger)
    let caught = false
    try:
        sync_halt(engine, ["arm", "rv"])
    catch e:
        caught = true
    assert_true(caught, "sync_halt on multiple sessions should raise when not connected")

add_test(suite, "sync: multi-session halt raises when not connected", test_sync_multiple_sessions_fails)

## --- RPC sync method tests ---

proc test_rpc_sync_halt_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "syncHalt", "params": {"sessions": ["arm"]}, "id": 1}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "syncHalt without connect should return error")

add_test(suite, "rpc: syncHalt without connect", test_rpc_sync_halt_not_connected)

proc test_rpc_sync_resume_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "syncResume", "params": {"sessions": ["arm"]}, "id": 2}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "syncResume without connect should return error")

add_test(suite, "rpc: syncResume without connect", test_rpc_sync_resume_not_connected)

proc test_rpc_sync_step_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "syncStep", "params": {"sessions": ["arm"]}, "id": 3}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "syncStep without connect should return error")

add_test(suite, "rpc: syncStep without connect", test_rpc_sync_step_not_connected)

proc test_rpc_sync_set_breakpoint_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "syncSetBreakpoint", "params": {"sessions": ["arm"], "addr": "0x8000"}, "id": 4}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "syncSetBreakpoint without connect should return error")

add_test(suite, "rpc: syncSetBreakpoint without connect", test_rpc_sync_set_breakpoint_not_connected)

proc test_rpc_get_merged_state_not_connected():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine
    from src.rpc.server import handle_request
    from src.timeline.recorder import create_timeline_recorder
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let sync_engine = create_sync_engine(sm, logger)
    let timeline = create_timeline_recorder(logger)

    let req = {"jsonrpc": "2.0", "method": "getMergedState", "params": {"sessions": ["arm"]}, "id": 5}
    let resp = handle_request(req, sm, sync_engine, timeline, logger)
    assert_true(dict_has(resp, "error"), "getMergedState without connect should return error")

add_test(suite, "rpc: getMergedState without connect", test_rpc_get_merged_state_not_connected)

## --- timeline recorder tests ---

proc test_timeline_create():
    from src.timeline.recorder import create_timeline_recorder
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let t = create_timeline_recorder(logger)
    assert_not_equal(t, nil, "timeline recorder should not be nil")
    assert_equal(t["recording"], false, "should not be recording initially")
    assert_equal(t["arm_events"], [], "arm events should start empty")
    assert_equal(t["rv_events"], [], "rv events should start empty")

add_test(suite, "timeline: create", test_timeline_create)

proc test_timeline_start_stop():
    from src.timeline.recorder import create_timeline_recorder, start_recording, stop_recording, is_recording
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let t = create_timeline_recorder(logger)
    assert_equal(is_recording(t), false, "should not be recording before start")
    start_recording(t)
    assert_equal(is_recording(t), true, "should be recording after start")
    let data = stop_recording(t)
    assert_equal(is_recording(t), false, "should not be recording after stop")
    assert_true(dict_has(data, "arm"), "stopped data should have arm key")
    assert_true(dict_has(data, "rv"), "stopped data should have rv key")

add_test(suite, "timeline: start/stop", test_timeline_start_stop)

proc test_timeline_record_event():
    from src.timeline.recorder import create_timeline_recorder, start_recording, record_event, stop_recording
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let t = create_timeline_recorder(logger)
    start_recording(t)
    record_event(t, "arm", "breakpoint", "0x8000", "hit")
    record_event(t, "rv", "step", "0x9000", "stepped")
    let data = stop_recording(t)
    assert_equal(len(data["arm"]), 1, "should have 1 arm event")
    assert_equal(len(data["rv"]), 1, "should have 1 rv event")
    assert_equal(data["arm"][0]["event_type"], "breakpoint", "arm event type should match")
    assert_equal(data["rv"][0]["event_type"], "step", "rv event type should match")
    assert_equal(data["arm"][0]["pc"], "0x8000", "arm pc should match")
    assert_equal(data["rv"][0]["pc"], "0x9000", "rv pc should match")

add_test(suite, "timeline: record events", test_timeline_record_event)

proc test_timeline_no_record_when_stopped():
    from src.timeline.recorder import create_timeline_recorder, start_recording, stop_recording, record_event, get_timeline
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let t = create_timeline_recorder(logger)
    record_event(t, "arm", "step", "0x8000", "data")
    let data = get_timeline(t)
    assert_equal(len(data["arm"]), 0, "should not record events when stopped")

add_test(suite, "timeline: no record when stopped", test_timeline_no_record_when_stopped)

proc test_timeline_clear():
    from src.timeline.recorder import create_timeline_recorder, start_recording, record_event, clear_timeline, get_timeline
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let t = create_timeline_recorder(logger)
    start_recording(t)
    record_event(t, "arm", "step", "0x8000", "data")
    clear_timeline(t)
    let data = get_timeline(t)
    assert_equal(len(data["arm"]), 0, "should be empty after clear")

add_test(suite, "timeline: clear", test_timeline_clear)

## --- flamegraph tests ---
proc test_flamegraph_create():
    from src.profiler.flamegraph import create_flamegraph_builder
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let builder = create_flamegraph_builder(logger)
    assert_not_equal(builder, nil, "builder should not be nil")
    assert_equal(builder["nodes"], {}, "nodes should start empty")

add_test(suite, "flamegraph: create builder", test_flamegraph_create)

proc test_flamegraph_add_trace():
    from src.profiler.flamegraph import create_flamegraph_builder, add_trace, generate_json
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let builder = create_flamegraph_builder(logger)
    add_trace(builder, ["main", "foo"], 10)
    add_trace(builder, ["main", "bar"], 5)
    let json = generate_json(builder)
    assert_equal(json["name"], "root", "root name")
    assert_equal(json["value"], 0, "root value")
    let children = json["children"]
    assert_equal(len(children), 1, "should have 1 main child")
    let main = children[0]
    assert_equal(main["name"], "main", "main name")
    assert_equal(main["value"], 15, "main total value")
    assert_equal(len(main["children"]), 2, "main should have 2 children")

add_test(suite, "flamegraph: add trace and generate json", test_flamegraph_add_trace)

## --- openocd trace tests ---
proc test_openocd_trace_methods_raise_not_connected():
    from src.adapters.openocd import OpenOCDAdapter
    from lib.log import create_logger
    let logger = create_logger("test", 1)
    let ocd = OpenOCDAdapter("localhost", 3333, logger)
    let start_ok = false
    try:
        ocd.start_trace()
    catch e:
        if e == "OpenOCD not connected":
            start_ok = true
    assert_true(start_ok, "start_trace should raise 'OpenOCD not connected'")
    
    let stop_ok = false
    try:
        ocd.stop_trace()
    catch e:
        if e == "OpenOCD not connected":
            stop_ok = true
    assert_true(stop_ok, "stop_trace should raise 'OpenOCD not connected'")

add_test(suite, "openocd: trace methods raise when not connected", test_openocd_trace_methods_raise_not_connected)

## --- sync poll test ---
proc test_sync_poll():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.sync.engine import create_sync_engine, sync_poll
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:1", "gdb_mi")
    let engine = create_sync_engine(sm, logger)
    let result = sync_poll(engine, ["arm"])
    assert_equal(result, true, "sync_poll should return true placeholder")

add_test(suite, "sync: poll placeholder", test_sync_poll)

run(suite)
report(suite)
