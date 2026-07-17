## Minimal JSON utilities for JSON-RPC 2.0.
## Avoids native module calls for codegen compatibility.

## Recursively convert a SageLang value to a JSON string.
proc json_stringify(value):
    let t = type(value)
    if t == "nil":
        return "null"
    if t == "bool":
        if value:
            return "true"
        return "false"
    if t == "number":
        return str(value)
    if t == "string":
        let s_result = "\""
        let chars = split(value, "")
        for ch in chars:
            if ch == "\"":
                s_result = s_result + "\\\""
            elif ch == "\\":
                s_result = s_result + "\\\\"
            elif ch == "\n":
                s_result = s_result + "\\n"
            elif ch == "\t":
                s_result = s_result + "\\t"
            else:
                s_result = s_result + ch
        return s_result + "\""
    if t == "array":
        let a_parts = []
        for elem in value:
            push(a_parts, json_stringify(elem))
        return "[" + join(a_parts, ",") + "]"
    if t == "dict":
        let d_parts = []
        let keys = dict_keys(value)
        for k in keys:
            let v = value[k]
            let pair = "\"" + k + "\":" + json_stringify(v)
            push(d_parts, pair)
        return "{" + join(d_parts, ",") + "}"
    return "null"

## Parse a JSON string into a SageLang value.
proc json_parse(text: String):
    let pos = 0
    let n = len(text)

    proc skip_ws():
        while pos < n:
            let ws_ch = text[pos]
            if ws_ch != " " and ws_ch != "\t" and ws_ch != "\n" and ws_ch != "\r":
                break
            pos = pos + 1

    proc parse_str():
        if pos >= n or text[pos] != "\"":
            return nil
        pos = pos + 1
        let str_buf = ""
        while pos < n:
            let str_ch = text[pos]
            if str_ch == "\"":
                pos = pos + 1
                return str_buf
            if str_ch == "\\":
                pos = pos + 1
                if pos < n:
                    let esc = text[pos]
                    if esc == "\"":
                        str_buf = str_buf + "\""
                    elif esc == "\\":
                        str_buf = str_buf + "\\"
                    elif esc == "n":
                        str_buf = str_buf + "\n"
                    elif esc == "t":
                        str_buf = str_buf + "\t"
                    elif esc == "/":
                        str_buf = str_buf + "/"
                    else:
                        str_buf = str_buf + esc
                pos = pos + 1
            else:
                str_buf = str_buf + str_ch
                pos = pos + 1
        return nil

    proc parse_num():
        let num_start = pos
        if pos < n and text[pos] == "-":
            pos = pos + 1
        while pos < n:
            let nc = text[pos]
            if nc >= "0" and nc <= "9":
                pos = pos + 1
            else:
                break
        if pos < n and text[pos] == ".":
            pos = pos + 1
            while pos < n:
                let nc2 = text[pos]
                if nc2 >= "0" and nc2 <= "9":
                    pos = pos + 1
                else:
                    break
        let num_str = text[num_start:pos]
        return tonumber(num_str)

    proc parse_val():
        skip_ws()
        if pos >= n:
            return nil
        let vc = text[pos]
        if vc == "\"":
            return parse_str()
        if vc == "-" or (vc >= "0" and vc <= "9"):
            return parse_num()
        if vc == "t":
            if text[pos:pos+4] == "true":
                pos = pos + 4
                return true
            return nil
        if vc == "f":
            if text[pos:pos+5] == "false":
                pos = pos + 5
                return false
            return nil
        if vc == "n":
            if text[pos:pos+4] == "null":
                pos = pos + 4
                return nil
            return nil
        if vc == "[":
            return parse_arr()
        if vc == "{":
            return parse_obj()
        return nil

    proc parse_arr():
        if pos >= n or text[pos] != "[":
            return nil
        pos = pos + 1
        let arr_buf = []
        skip_ws()
        if pos < n and text[pos] == "]":
            pos = pos + 1
            return arr_buf
        while true:
            let av = parse_val()
            push(arr_buf, av)
            skip_ws()
            if pos >= n:
                return arr_buf
            if text[pos] == ",":
                pos = pos + 1
            elif text[pos] == "]":
                pos = pos + 1
                return arr_buf
            else:
                return arr_buf

    proc parse_obj():
        if pos >= n or text[pos] != "{":
            return nil
        pos = pos + 1
        let obj_buf = {}
        skip_ws()
        if pos < n and text[pos] == "}":
            pos = pos + 1
            return obj_buf
        while true:
            let ok = parse_str()
            skip_ws()
            if pos >= n or text[pos] != ":":
                return obj_buf
            pos = pos + 1
            let ov = parse_val()
            obj_buf[ok] = ov
            skip_ws()
            if pos >= n:
                return obj_buf
            if text[pos] == ",":
                pos = pos + 1
            elif text[pos] == "}":
                pos = pos + 1
                return obj_buf
            else:
                return obj_buf

    skip_ws()
    return parse_val()
