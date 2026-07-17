## JanusDBG backend entry point.
import std.log
import std.argparse
import sys

from lib.log import create_logger
from src.rpc.server import start_server
from src.session.session import SessionManager

## Main entry point for the JanusDBG backend.
proc main():
    let parser = argparse.create("janusdbgd", "Unified ARM+RISC-V debugger backend")
    argparse.add_option(parser, "arm-host", "a", "ARM GDB host:port", "localhost:2331")
    argparse.add_option(parser, "rv-host", "r", "RISC-V OpenOCD host:port", "localhost:3333")
    argparse.add_option(parser, "rpc-port", "p", "RPC server port", "8179")
    argparse.add_flag(parser, "verbose", "v", "Verbose logging")
    argparse.add_positional(parser, "config", "Config file path", false)

    let args = argparse.parse(parser, sys.args())
    let log_level = log.INFO
    if argparse.get_flag(args, "verbose"):
        log_level = log.DEBUG
    let logger = create_logger("janusdbg", log_level)

    log.info(logger, "JanusDBG starting")

    let sm = SessionManager(logger)
    let arm_host = argparse.get_option(args, "arm-host")
    let rv_host = argparse.get_option(args, "rv-host")
    let rpc_port = tonumber(argparse.get_option(args, "rpc-port"))

    log.info(logger, "ARM target: " + arm_host)
    log.info(logger, "RISC-V target: " + rv_host)
    log.info(logger, "RPC server port: " + str(rpc_port))

    sm.register_session("arm", arm_host)
    sm.register_session("rv", rv_host)

    start_server(rpc_port, sm, logger)
    log.info(logger, "JanusDBG shutting down")

try:
    main()
catch e:
    print "FATAL: " + e
    sys.exit(1)
