module Options = struct
  (* Components of the compiler *)
  type component = General | Lexer | Parser | TypeChecker

  type debug_options = {
    debug : bool; (* Show debug output  *)
    unicode : bool; (* Use unicode output *)
    roundoff : int option; (* Set unit roundoff *)
  }

  let debug_default = { debug = false; unicode = true; roundoff = None }
  let debug_options = ref debug_default
end

module FileInfo = struct
  type info = FI of string * int * int | UNKNOWN
  type 'a withinfo = { i : info; v : 'a }

  let dummyinfo = UNKNOWN
  let createInfo f l c = FI (f, l, c)

  let pp_fileinfo ppf = function
    | FI (f, l, c) ->
        let f_l = String.length f in
        let f_t = min f_l 12 in
        let f_s = max 0 (f_l - f_t) in
        let short_file = String.sub f f_s f_t in
        Format.fprintf ppf "(%s:%02d.%02d): " short_file l c
    | UNKNOWN -> Format.fprintf ppf ""
end

module Error = struct
  open Options

  exception Exit of int

  let comp_to_string = function
    | General -> "[General]"
    | Lexer -> "[Lexer  ]"
    | Parser -> "[Parser ]"
    | TypeChecker -> "[TyCheck]"

  (* Default print function *)
  let message debug component fi =
    if (not debug) || !debug_options.debug then (
      Format.eprintf "@[%s %a@[" (comp_to_string component) FileInfo.pp_fileinfo
        fi;
      Format.kfprintf
        (fun ppf -> Format.fprintf ppf "@]@]@.")
        Format.err_formatter)
    else Format.ifprintf Format.err_formatter

  (* Error message print functions *)
  let error_msg comp fi =
    let cont _ =
      Format.eprintf "@]@.";
      raise (Exit 1)
    in
    Format.eprintf "@[%s %a" (comp_to_string comp) FileInfo.pp_fileinfo fi;
    Format.kfprintf cont Format.err_formatter

  let error_msg_pp comp fi pp v =
    Format.eprintf "@[%s %a%a@." (comp_to_string comp) FileInfo.pp_fileinfo fi
      pp v;
    raise (Exit 1)
end
