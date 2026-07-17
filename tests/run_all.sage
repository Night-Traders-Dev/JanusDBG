## Test runner for JanusDBG.
import std.testing
import std.log

let suite = testing.create_suite("JanusDBG Core Tests")

## Test logging module
proc test_log_create():
    from lib.log import create_logger
    let logger = create_logger("test", log.INFO)
    testing.assert_not_equal(logger, nil, "logger should not be nil")

testing.add_test(suite, "log: create_logger", test_log_create)

## Test session manager
proc test_session_create():
    import std.log
    from lib.log import create_logger
    from src.session.session import SessionManager
    let logger = create_logger("test", log.INFO)
    let sm = SessionManager(logger)
    testing.assert_not_equal(sm, nil, "session manager should not be nil")

testing.add_test(suite, "session: create", test_session_create)

proc test_session_register():
    from lib.log import create_logger
    from src.session.session import SessionManager
    let logger = create_logger("test", log.INFO)
    let sm = SessionManager(logger)
    sm.register_session("arm", "localhost:2331")
    let sessions = sm.get_sessions()
    testing.assert_true(dict_has(sessions, "arm"), "arm session should exist")

testing.add_test(suite, "session: register", test_session_register)

testing.run(suite)
testing.report(suite)
