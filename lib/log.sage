## Minimal logger compatible with C/LLVM codegen backends.
## Avoids std.log which uses indirect callbacks not supported by backends.

let LOG_NAMES = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]

## Create a logger with a name and minimum level.
proc create_logger(name: String, level=1):
    return {"name": name, "level": level}

## Internal: format and print a log message.
proc log_print(logger, level: Number, msg: String):
    let name = logger["name"]
    let idx = level
    if idx < 0:
        idx = 0
    if idx > 4:
        idx = 4
    let label = LOG_NAMES[idx]
    print "[" + label + "] " + name + ": " + msg

## Log a debug message.
proc debug(logger, msg: String):
    if logger["level"] <= 0:
        log_print(logger, 0, msg)

## Log an info message.
proc info(logger, msg: String):
    if logger["level"] <= 1:
        log_print(logger, 1, msg)

## Log a warning message.
proc warn(logger, msg: String):
    if logger["level"] <= 2:
        log_print(logger, 2, msg)

## Log an error message.
proc error(logger, msg: String):
    if logger["level"] <= 3:
        log_print(logger, 3, msg)

## Log a fatal message.
proc fatal(logger, msg: String):
    if logger["level"] <= 4:
        log_print(logger, 4, msg)
