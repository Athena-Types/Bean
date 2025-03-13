open Format
open Syntax
open Support.Options

(* Unicode handling *)
module Symbols = struct
  type pp_symbols = DblArrow | Tensor | Union | Bang | Num | Eps | Lub

  let pp_symbol_table s =
    match s with
    | DblArrow -> ("=>", "⇒")
    | Tensor -> ("x", "⊗")
    | Union -> ("+", "⊕")
    | Bang -> ("!", "!")
    | Num -> ("num", "ℝ")
    | Eps -> ("e", "ε")
    | Lub -> ("U", "⊔")

  let string_of_symbol s =
    let select = if !debug_options.unicode then snd else fst in
    select (pp_symbol_table s)
end

let u_sym x = Symbols.string_of_symbol x

(* Pretty printing for lists *)
let rec pp_list pp fmt l =
  match l with
  | [] -> fprintf fmt ""
  | csx :: [] -> fprintf fmt "%a" pp csx
  | csx :: csl -> fprintf fmt "%a,@ %a" pp csx (pp_list pp) csl

let rec pp_rev_list pp fmt l =
  match l with
  | [] -> fprintf fmt ""
  | csx :: [] -> fprintf fmt "%a" pp csx
  | csx :: csl -> fprintf fmt "%a,@ %a" (pp_rev_list pp) csl pp csx

(* Pretty printing for variables *)
let pp_name fmt n = fprintf fmt "%s" n
let pp_vinfo fmt v = fprintf fmt "%a" pp_name v.v_name
let pp_binfo fmt b = pp_name fmt b.b_name

(* Pretty printing for errors *)
let rec pp_be fmt s =
  match s with
  | BeConst flt -> 
    (match !debug_options.roundoff with
      None -> fprintf fmt "[%s%s]" (string_of_float flt) (u_sym Symbols.Eps)
    | Some n -> 
        let u = 2. ** (float_of_int (-n)) in
        let eps = u /. (1. -. u) in
        fprintf fmt "[%.2e]" (flt *. eps))
  | BeAdd (e1, e2) -> fprintf fmt "(%a + %a)" pp_be e1 pp_be e2
  | BeLub (e1, e2) ->
      fprintf fmt "(%a @<1>%s %a)" pp_be e1 (u_sym Symbols.Lub) pp_be e2

let pp_be_op fmt o =
  match o with
  | None -> fprintf fmt "?"
  | Some e -> pp_be fmt (Syntax.be_simpl e)

let pp_be_op_list = pp_list pp_be_op

(* Pretty printing for types *)

(* Primitive types *)
let pp_primtype fmt ty =
  match ty with
  | PrimNum -> fprintf fmt "@<1>%s" (u_sym Symbols.Num)
  | PrimDNum -> fprintf fmt "@<1>d%s" (u_sym Symbols.Num)
  | PrimUnit -> fprintf fmt "()"

(* Main printer *)
let rec pp_type ppf ty =
  match ty with
  | TyPrim tp -> fprintf ppf "%a" pp_primtype tp
  | TyUnion (ty1, ty2) ->
      fprintf ppf "(%a @<1>%s @[<h>%a@])" pp_type ty1 (u_sym Symbols.Union)
        pp_type ty2
  | TyTensor (ty1, ty2) ->
      fprintf ppf "(%a @<1>%s @[<h>%a@])" pp_type ty1 (u_sym Symbols.Tensor)
        pp_type ty2

(* Pretty printing for contexts *)
let pp_var_ctx_elem ppf (v, ty) =
  fprintf ppf "%a : @[%a@]" pp_vinfo v pp_type ty

let pp_var_ctx = pp_rev_list pp_var_ctx_elem

let pp_var_ctx_elem_be ppf ((v, ty), be) =
  fprintf ppf "%a :%a @[%a@]" pp_vinfo v pp_be_op be pp_type ty

let pp_var_ctx_be = pp_rev_list pp_var_ctx_elem_be

(* Pretty printing for terms *)
let rec pp_term ppf t =
  match t with
  | TmVar (_, v) -> fprintf ppf "%a" pp_vinfo v
  | TmDVar (_, v) -> fprintf ppf "%a" pp_vinfo v
  | TmDisc (_, tm) -> fprintf ppf "!%a" pp_term tm
  | TmPrim (_, _pt) -> fprintf ppf "%s" "()"
  | TmTens (_, tm1, tm2) ->
      fprintf ppf "(@[%a@], @[%a@])" pp_term tm1 pp_term tm2
  | TmTensDest (_, x, y, tm, term) ->
      fprintf ppf "@[<v>let (%a, %a) := @[%a@];@,@[%a@]@]" pp_binfo x pp_binfo y
        pp_term tm pp_term term
  | TmTensDDest (_, x, y, tm, term) ->
      fprintf ppf "@[<v>dlet (%a, %a) := @[%a@];@,@[%a@]@]" pp_binfo x pp_binfo
        y pp_term tm pp_term term
  | TmAdd (_, x, y) -> fprintf ppf "%a + %a" pp_vinfo x pp_vinfo y
  | TmSub (_, x, y) -> fprintf ppf "%a - %a" pp_vinfo x pp_vinfo y
  | TmMul (_, x, y) -> fprintf ppf "%a * %a" pp_vinfo x pp_vinfo y
  | TmDiv (_, x, y) -> fprintf ppf "%a / %a" pp_vinfo x pp_vinfo y
  | TmDMul (_, x, y) -> fprintf ppf "%a d* %a" pp_vinfo x pp_vinfo y
  | TmLet (_, n, _sty, tm1, tm2) ->
      fprintf ppf "@[<v>let @[<hov>%a =@;<1 1>@[%a@]@];@,@[%a@]@]" pp_binfo n
        pp_term tm1 pp_term tm2
  | TmDLet (_, n, _sty, tm1, tm2) ->
      fprintf ppf "@[<v>dlet @[<hov>%a =@;<1 1>@[%a@]@];@,@[%a@]@]" pp_binfo n
        pp_term tm1 pp_term tm2
  | TmBind (_, n, _sty, tm1, tm2) ->
      fprintf ppf "@[<v>bind @[<hov>%a =@;<1 1>@[%a@]@];@,@[%a@]@]" pp_binfo n
        pp_term tm1 pp_term tm2
  | TmInl (_, ty, tm_l) ->
      fprintf ppf "inl @[%a@] @[%a@]" pp_type ty pp_term tm_l
  | TmInr (_, ty, tm_r) ->
      fprintf ppf "inr @[%a@] @[%a@]" pp_type ty pp_term tm_r
  | TmUnionCase (_, tm, ln, ltm, rn, rtm) ->
      fprintf ppf
        "case @[%a@] of {@\n\
        \   inl(%a) @<1>%s @[%a@]@\n\
        \ | inr(%a) @<1>%s @[%a@]@\n\
         }"
        pp_term tm pp_binfo ln (u_sym Symbols.DblArrow) pp_term ltm pp_binfo rn
        (u_sym Symbols.DblArrow) pp_term rtm
