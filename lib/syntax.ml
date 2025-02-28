open Support.FileInfo

(* Binders are represented using Debruijn notation *)

type var_info = {
  (* Indices start at 0 *)
  v_index : int;
  v_name : string;
}

type binder_info = { b_name : string }

(* Create a new binder *)
let nb_var n = { b_name = n }

(* Backward errors *)
type be = BeConst of float | BeAdd of be * be | BeLub of be * be
type obe = be option

(* Extension of operations on regular errors to optional errors *)
let add_obe (obe1 : obe) (obe2 : obe) : obe =
  match (obe1, obe2) with
  | Some be1, Some be2 -> Some (BeAdd (be1, be2))
  | _, _ -> None

let lub_obe (obe1 : obe) (obe2 : obe) : obe =
  match (obe1, obe2) with
  | Some be1, Some be2 -> Some (BeLub (be1, be2))
  | Some be, None | None, Some be -> Some be
  | None, None -> None

let intersect_obe (a : obe) (b : obe) : bool =
  (not (a == None)) && not (b == None)

(* Lists of optional errors *)

(* A list with None errors *)
let nones (n : int) : obe list =
  let rec aux n l = if n = 0 then l else aux (n - 1) (None :: l) in
  aux n []

(* A list with None errors, except for one variable *)
let singleton (n : int) (v : var_info) (be : be) : obe list =
  let rec aux n l =
    if n = 0 then l
    else
      let si = if n = v.v_index + 1 then Some be else None in
      aux (n - 1) (si :: l)
  in
  aux n []

(* A list with None errors, except for two variables *)
let binop_ctx (n : int) (v1 : var_info) (v2 : var_info) e1 e2 : obe list =
  let rec aux n l =
    if n = 0 then l
    else
      let si =
        if n = v1.v_index + 1 then Some e1
        else if n = v2.v_index + 1 then Some e2
        else None
      in
      aux (n - 1) (si :: l)
  in
  aux n []

(* If contexts are not disjoint, takes greater of error bounds *)
let rec union_ctx' (ctx : (obe * obe) list) : obe list =
  match ctx with
  | (Some s1, Some s2) :: l -> lub_obe (Some s1) (Some s2) :: union_ctx' l
  | (Some s1, _) :: l -> Some s1 :: union_ctx' l
  | (_, Some s2) :: l -> Some s2 :: union_ctx' l
  | (None, None) :: l -> None :: union_ctx' l
  | [] -> []

let union_ctx (ctx1 : obe list) (ctx2 : obe list) : obe list =
  union_ctx' (List.combine ctx1 ctx2)

let shift_err (be : obe) (l : obe list) : obe list =
  match be with Some _ -> List.map (add_obe be) l | None -> l

(* Returns Some _ if the two contexts are not disjoint *)
let check_disjoint (ctx1 : obe list) (ctx2 : obe list) : bool option =
  List.find_opt (fun a -> a == true) (List.map2 intersect_obe ctx1 ctx2)

let m_zero = 0.0
let m_hlf = 0.5
let m_one = 1.0
let be_zero = BeConst m_zero
let be_hlf = BeConst m_hlf
let be_one = BeConst m_one
let max c1 c2 = if c1 <= c2 then c2 else c1

(* Simplifies a backward error expression *)
let rec be_simpl (bes : be) =
  match bes with
  | BeAdd (be1, be2) -> (
      let be1' = be_simpl be1 in
      let be2' = be_simpl be2 in
      match (be1', be2') with
      | BeConst be1'', BeConst be2'' -> BeConst (be1'' +. be2'')
      | _, _ -> bes)
  | BeLub (be1, be2) -> (
      let be1' = be_simpl be1 in
      let be2' = be_simpl be2 in
      match (be1', be2') with
      | BeConst be1'', BeConst be2'' -> BeConst (max be1'' be2'')
      | _, _ -> bes)
  | _ -> bes

(* Primitive types *)
type ty_prim = PrimNum | PrimDNum | PrimUnit

(* Types *)
type ty = TyPrim of ty_prim | TyUnion of ty * ty | TyTensor of ty * ty

(* Primitive Terms *)
type term_prim = PrimTUnit

let type_of_prim = TyPrim PrimUnit
let dummy_ty = TyPrim PrimUnit

(* Turns linear type into discrete type *)
let rec disc t =
  match t with
  | TyPrim PrimNum -> TyPrim PrimDNum
  | TyUnion (t1, t2) -> TyUnion (disc t1, disc t2)
  | TyTensor (t1, t2) -> TyTensor (disc t1, disc t2)
  | _ -> t

let disc_obe t = match t with Some t -> Some (disc t) | None -> None

(* Turns discrete type into linear type *)
let rec linear t =
  match t with
  | TyPrim PrimDNum -> TyPrim PrimNum
  | TyUnion (t1, t2) -> TyUnion (linear t1, linear t2)
  | TyTensor (t1, t2) -> TyTensor (linear t1, linear t2)
  | _ -> t

(* Terms *)
type op = AddOp | MulOp | DivOp | SubOp

type term =
  | TmVar of info * var_info
  | TmDVar of info * var_info
  | TmDisc of info * term
  | TmPrim of info * term_prim
  (* Tensor *)
  | TmTens of info * term * term
  | TmTensDest of info * binder_info * binder_info * term * term
  | TmTensDDest of info * binder_info * binder_info * term * term
  (* Case *)
  | TmInl of info * ty * term
  | TmInr of info * ty * term
  | TmUnionCase of info * term * binder_info * term * binder_info * term
  (* Let bindings *)
  | TmLet of info * binder_info * ty option * term * term
  | TmDLet of info * binder_info * ty option * term * term
  | TmBind of info * binder_info * ty option * term * term
  (* Basic ops *)
  | TmAdd of info * var_info * var_info
  | TmSub of info * var_info * var_info
  | TmDiv of info * var_info * var_info
  | TmMul of info * var_info * var_info
  | TmDMul of info * var_info * var_info

(* File info extraction *)
let tm_info t =
  match t with
  | TmVar (fi, _) -> fi
  | TmDVar (fi, _) -> fi
  | TmDisc (fi, _) -> fi
  | TmPrim (fi, _) -> fi
  | TmTens (fi, _, _) -> fi
  | TmTensDest (fi, _, _, _, _) -> fi
  | TmTensDDest (fi, _, _, _, _) -> fi
  | TmInl (fi, _, _) -> fi
  | TmInr (fi, _, _) -> fi
  | TmUnionCase (fi, _, _, _, _, _) -> fi
  | TmLet (fi, _, _, _, _) -> fi
  | TmDLet (fi, _, _, _, _) -> fi
  | TmBind (fi, _, _, _, _) -> fi
  | TmAdd (fi, _, _) -> fi
  | TmSub (fi, _, _) -> fi
  | TmDiv (fi, _, _) -> fi
  | TmMul (fi, _, _) -> fi
  | TmDMul (fi, _, _) -> fi
