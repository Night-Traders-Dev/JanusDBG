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
    ## These should not crash regardless of level
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
    sm_register(sm, "arm", "localhost:2331")
    let sessions = sm_get_sessions(sm)
    assert_true(dict_has(sessions, "arm"), "arm session should exist")
    let arm = sessions["arm"]
    assert_equal(arm["target"], "localhost:2331", "target should match")
    assert_equal(arm["connected"], false, "should start disconnected")

add_test(suite, "session: register", test_session_register)

proc test_session_multiple():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_get_sessions
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "host1:2331")
    sm_register(sm, "rv", "host2:3333")
    let sessions = sm_get_sessions(sm)
    assert_equal(len(sessions), 2, "should have 2 sessions")

add_test(suite, "session: register multiple", test_session_multiple)

proc test_session_connect():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_connect, sm_get_sessions
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:2331")
    sm_connect(sm, "arm")
    let arm = sm_get_sessions(sm)["arm"]
    assert_equal(arm["connected"], true, "should be connected")

add_test(suite, "session: connect", test_session_connect)

proc test_session_disconnect():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register, sm_connect, sm_disconnect, sm_get_sessions
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:2331")
    sm_connect(sm, "arm")
    sm_disconnect(sm, "arm")
    let arm = sm_get_sessions(sm)["arm"]
    assert_equal(arm["connected"], false, "should be disconnected")

add_test(suite, "session: disconnect", test_session_disconnect)

## --- GDB/MI adapter tests ---

proc test_gdb_create():
    from lib.log import create_logger
    from src.adapters.gdb_mi import GDBMIAdapter
    let logger = create_logger("test", 1)
    let gdb = GDBMIAdapter("localhost", 2331, logger)
    assert_not_equal(gdb, nil, "adapter should not be nil")
    assert_equal(gdb.connected, false, "should start disconnected")

add_test(suite, "gdb_mi: create", test_gdb_create)

proc test_gdb_methods():
    from lib.log import create_logger
    from src.adapters.gdb_mi import GDBMIAdapter
    let logger = create_logger("test", 1)
    let gdb = GDBMIAdapter("localhost", 2331, logger)
    gdb.connected = true
    let bp = gdb.set_breakpoint("*0x8000")
    let step = gdb.step()
    let cnt = gdb.cont()
    let regs = gdb.read_registers()
    assert_true(true, "GDB methods should not crash")

add_test(suite, "gdb_mi: methods", test_gdb_methods)

## --- OpenOCD adapter tests ---

proc test_ocd_create():
    from lib.log import create_logger
    from src.adapters.openocd import OpenOCDAdapter
    let logger = create_logger("test", 1)
    let ocd = OpenOCDAdapter("localhost", 3333, logger)
    assert_not_equal(ocd, nil, "adapter should not be nil")
    assert_equal(ocd.connected, false, "should start disconnected")

add_test(suite, "openocd: create", test_ocd_create)

proc test_ocd_methods():
    from lib.log import create_logger
    from src.adapters.openocd import OpenOCDAdapter
    let logger = create_logger("test", 1)
    let ocd = OpenOCDAdapter("localhost", 3333, logger)
    ocd.connected = true
    ocd.halt()
    ocd.resume()
    ocd.step()
    ocd.set_breakpoint("0x80000000")
    ocd.read_reg("pc")
    assert_true(true, "OpenOCD methods should not crash")

add_test(suite, "openocd: methods", test_ocd_methods)

## --- RPC server tests ---

proc test_rpc_request():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.rpc.server import handle_request
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:2331")

    let req = {"jsonrpc": "2.0", "method": "getSessions", "id": 1}
    let resp = handle_request(req, sm, logger)
    assert_equal(resp["jsonrpc"], "2.0", "response should be jsonrpc 2.0")

add_test(suite, "rpc: basic request", test_rpc_request)

proc test_rpc_connect():
    from lib.log import create_logger
    from src.session.session import create_session_manager, sm_register
    from src.rpc.server import handle_request
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)
    sm_register(sm, "arm", "localhost:2331")

    let req = {"jsonrpc": "2.0", "method": "connect", "params": {"session": "arm"}, "id": 2}
    let resp = handle_request(req, sm, logger)
    assert_equal(resp["result"], "connected", "should respond connected")
    assert_equal(resp["id"], 2, "id should match")

add_test(suite, "rpc: connect", test_rpc_connect)

proc test_rpc_unknown_method():
    from lib.log import create_logger
    from src.session.session import create_session_manager
    from src.rpc.server import handle_request
    let logger = create_logger("test", 1)
    let sm = create_session_manager(logger)

    let req = {"jsonrpc": "2.0", "method": "unknownMethod", "id": 3}
    let resp = handle_request(req, sm, logger)
    assert_equal(resp["error"]["code"], -32601, "should return method not found error")

add_test(suite, "rpc: unknown method", test_rpc_unknown_method)

run(suite)
report(suite)
