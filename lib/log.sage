## Logging utilities wrapping std.log.
import std.log

## Create a named logger with a given level.
proc create_logger(name: String, level=log.INFO):
    let logger = log.create(name, level)
    return logger

## Log a debug message.
proc debug(logger, msg: String):
    log.debug(logger, msg)

## Log an info message.
proc info(logger, msg: String):
    log.info(logger, msg)

## Log a warning message.
proc warn(logger, msg: String):
    log.warn(logger, msg)

## Log an error message.
proc error(logger, msg: String):
    log.error(logger, msg)

## Log a fatal message.
proc fatal(logger, msg: String):
    log.fatal(logger, msg)
