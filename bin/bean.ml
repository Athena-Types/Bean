open Support.Options
open Support.Error

let infile = ref ("" : string)

let argDefs =
  [
    ( "-d",
      Arg.Unit (fun () -> debug_options := { !debug_options with debug = true }),
      " Set debug output" );
    ( "--debug",
      Arg.Unit (fun () -> debug_options := { !debug_options with debug = true }),
      " Set debug output" );
    ( "--disable-unicode",
      Arg.Unit
        (fun () -> debug_options := { !debug_options with unicode = false }),
      " Disable unicode printing" );
    ( "--unit-roundoff",
      Arg.Int (fun n -> debug_options := { !debug_options with roundoff = Some n }), 
      " Set unit roundoff value to 2^(-n)" );
    ( "-u",
      Arg.Int (fun n -> debug_options := { !debug_options with roundoff = Some n }), 
      " Set unit roundoff value to 2^(-n)" );
  ]

let dp = Support.FileInfo.dummyinfo
let main_error = error_msg General
let main_info fi = message false General fi
let main_debug fi = message true General fi

let parseArgs () =
  let inFile = ref (None : string option) in
  Arg.parse argDefs
    (fun s ->
      match !inFile with
      | Some _ -> main_error dp "You must specify exactly one input file"
      | None -> inFile := Some s)
    "Usage: bean [options] inputfile";
  match !inFile with
  | None ->
      main_error dp "No input file specified (use --help to display usage info)";
      ""
  | Some s -> s

(* Parse the input *)
let parse file =
  let readme, writeme = Unix.pipe () in
  ignore
    (Unix.create_process "cpp" [| "cpp"; "-w"; file |] Unix.stdin writeme
       Unix.stderr);
  Unix.close writeme;
  let pi = Unix.in_channel_of_descr readme in
  let lexbuf = Lexer.create file pi in
  let context, dcontext, program =
    try Parser.body Lexer.main lexbuf
    with Parser.Error -> error_msg Parser (Lexer.info lexbuf) "Parse error"
  in
  Parsing.clear_parser ();
  close_in pi;
  (context, dcontext, program)

let type_check program context dcontext =
  let ty, ctx = Ty_bi.get_type program context dcontext in
  main_info dp "Type of the program: @[%a@]" Print.pp_type ty;
  main_info dp "Inferred linear context:@\n@[%a@]" Print.pp_var_ctx_be
    (List.combine context ctx)

let get_terminal_size () =
  let in_channel = Unix.open_process_in "stty size" in
  try
    try
      let sc = Scanf.Scanning.from_channel in_channel in
      Scanf.bscanf sc "%d %d" (fun rows cols ->
          ignore (Unix.close_process_in in_channel);
          (rows, cols))
    with End_of_file ->
      ignore (Unix.close_process_in in_channel);
      (0, 0)
  with e ->
    ignore (Unix.close_process_in in_channel);
    raise e

let main () =
  (* Setup the pretty printing engine *)
  let fmt_margin =
    try snd (get_terminal_size ())
    with _ ->
      main_info dp "Failed to get terminal size value.";
      120
  in

  let set_pp fmt =
    Format.pp_set_ellipsis_text fmt "[...]";
    Format.pp_set_margin fmt (fmt_margin + 1);
    Format.pp_set_max_indent fmt fmt_margin
  in

  set_pp Format.std_formatter;
  set_pp Format.err_formatter;

  (* Read the command-line arguments *)
  infile := parseArgs ();

  let context, dcontext, program = parse !infile in

  (* Print the results of the parsing phase *)
  main_debug dp "Parsed discrete context:@\n@[%a@]" Print.pp_var_ctx dcontext;
  main_debug dp "Parsed linear context:@\n@[%a@]" Print.pp_var_ctx context;
  main_debug dp "Parsed program:@\n@[%a@]" Print.pp_term program;

  type_check program context dcontext

let time f x =
  let t = Sys.time () in
  let fx = f x in
  Printf.printf "Execution time: %fs\n" (Sys.time () -. t);
  fx

let res =
  try
    time main ();
    0
  with Exit x -> x

let () = exit res
