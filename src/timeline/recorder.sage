from sys import clock
from lib.log import info

proc create_timeline_recorder(logger):
    return {
        "logger": logger,
        "recording": false,
        "arm_events": [],
        "rv_events": [],
        "start_time": 0.0
    }

proc start_recording(recorder):
    recorder["recording"] = true
    recorder["arm_events"] = []
    recorder["rv_events"] = []
    recorder["start_time"] = clock()
    info(recorder["logger"], "Timeline recording started")

proc stop_recording(recorder):
    recorder["recording"] = false
    let result = {
        "arm": recorder["arm_events"],
        "rv": recorder["rv_events"]
    }
    info(recorder["logger"], "Timeline recording stopped")
    return result

proc get_timeline(recorder):
    return {
        "arm": recorder["arm_events"],
        "rv": recorder["rv_events"]
    }

proc clear_timeline(recorder):
    recorder["arm_events"] = []
    recorder["rv_events"] = []
    info(recorder["logger"], "Timeline cleared")

proc record_event(recorder, core: String, event_type: String, pc: String, data: String):
    if recorder["recording"]:
        let elapsed = clock() - recorder["start_time"]
        let event = {
            "timestamp": elapsed,
            "event_type": event_type,
            "pc": pc,
            "data": data
        }
        if core == "arm":
            push(recorder["arm_events"], event)
        else:
            push(recorder["rv_events"], event)

proc is_recording(recorder):
    return recorder["recording"]
