open Syntax

(* Contexts of type 'a *)
type 'a ctx = (var_info * 'a) list
type context = ty ctx

let length ctx = List.length ctx
let empty_context = []

(* Return a binding if it exists. Let the caller handle the error *)
let rec lookup_var id ctx =
  match ctx with
  | [] -> None
  | (var, value) :: l ->
      if var.v_name = id then Some (var, value) else lookup_var id l

(* Helper to modify the index *)
let var_shift o n v =
  { v with v_index = (if o <= v.v_index then v.v_index + n else v.v_index) }

(* Shifting of v_names *)
let varctx_var_shift n d ctx =
  List.map (fun (v, ty) -> (var_shift n d v, ty)) ctx

(* Extend the context with a new variable binding *)
let extend_var id bi ctx =
  let n_var = { v_name = id; v_index = 0 } in
  let s_ctx = varctx_var_shift 0 1 ctx in
  (n_var, bi) :: s_ctx

let extend_dummy_var id ctx = extend_var id dummy_ty ctx

(* Accessing the variable in the context *)
let access_var ctx i = List.nth ctx i
