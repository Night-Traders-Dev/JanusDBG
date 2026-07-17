## JanusDBG backend entry point.
from std.argparse import create, add_option, add_flag, add_positional, parse, get_flag, get_option
from sys import args, exit as sys_exit

from lib.log import create_logger, info
from src.rpc.server import start_server
from src.session.session import create_session_manager, sm_register

let LOG_DEBUG = 0
let LOG_INFO = 1

## Main entry point for the JanusDBG backend.
proc main():
    let parser = create("janusdbgd", "Unified ARM+RISC-V debugger backend")
    add_option(parser, "arm-host", "a", "ARM GDB host:port", "localhost:2331")
    add_option(parser, "rv-host", "r", "RISC-V OpenOCD host:port", "localhost:3333")
    add_option(parser, "rpc-port", "p", "RPC server port", "8179")
    add_flag(parser, "verbose", "v", "Verbose logging")
    add_positional(parser, "config", "Config file path", false)

    let parsed_args = parse(parser, args())
    let log_level = LOG_INFO
    if get_flag(parsed_args, "verbose"):
        log_level = LOG_DEBUG
    let logger = create_logger("janusdbg", log_level)

    info(logger, "JanusDBG starting")

    let sm = create_session_manager(logger)
    let arm_host = get_option(parsed_args, "arm-host")
    let rv_host = get_option(parsed_args, "rv-host")
    let rpc_port = tonumber(get_option(parsed_args, "rpc-port"))

    info(logger, "ARM target: " + arm_host)
    info(logger, "RISC-V target: " + rv_host)
    info(logger, "RPC server port: " + str(rpc_port))

    sm_register(sm, "arm", arm_host)
    sm_register(sm, "rv", rv_host)

    start_server(rpc_port, sm, logger)
    info(logger, "JanusDBG shutting down")

try:
    main()
catch e:
    print "FATAL: " + e
    sys_exit(1)
