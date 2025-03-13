open Context
open Syntax
open Format
open Print
open Support.Error
open Support.FileInfo

(* Errors *)
type ty_error_elem =
  | LetNotLinear of string
  | LetNotLinear2 of string * string
  | ProdNotLinear
  | TypeMismatch of ty * ty
  | WrongType of ty * ty
  | WrongShape of ty * string
  | NonZeroErr of string
  | NotDiscrete of ty
  | Internal of string

let ty_seq = ref 0
let ty_error_pp = error_msg_pp Support.Options.TypeChecker
let ty_debug fi = message true Support.Options.TypeChecker fi

type 'a ty_error = Right of 'a | Left of ty_error_elem withinfo

(* Reader/error monad for type-checking *)
type 'a checker = context -> context -> 'a ty_error

let ( >>= ) (m : 'a checker) (f : 'a -> 'b checker) : 'b checker =
 fun ctx dctx ->
  match m ctx dctx with Right res -> f res ctx dctx | Left e -> Left e

let ( >> ) m f = m >>= fun _ -> f
let return (x : 'a) : 'a checker = fun _ctx _dctx -> Right x
let get_ctx : context checker = fun ctx _ -> Right ctx
let get_dctx : context checker = fun _ dctx -> Right dctx

let get_ctx_length : int checker =
  get_ctx >>= fun ctx -> return @@ List.length ctx

let with_new_ctx (f : context -> context) (m : 'a checker) : 'a checker =
 fun ctx dctx -> m (f ctx) dctx

let with_new_dctx (f : context -> context) (m : 'a checker) : 'a checker =
 fun ctx dctx -> m ctx (f dctx)

let get_var_ty (v : var_info) : ty checker =
  get_ctx >>= fun ctx -> return @@ snd (access_var ctx v.v_index)

let get_dvar_ty (v : var_info) : ty checker =
  get_dctx >>= fun dctx -> return @@ snd (access_var dctx v.v_index)

let fail (i : info) (e : ty_error_elem) : 'a checker =
 fun _ _ -> Left { i; v = e }

module TypeSub = struct
  let check_prim_eq (i : info) (ty_f : ty_prim) (ty_a : ty_prim) : unit checker =
    if ty_f = ty_a then return ()
    else fail i @@ TypeMismatch (TyPrim ty_f, TyPrim ty_a)

  let rec check_type_eq (i : info) (ty_1 : ty) (ty_2 : ty) : unit checker =
    match (ty_1, ty_2) with
    | TyPrim p1, TyPrim p2 -> check_prim_eq i p1 p2
    | TyUnion (tyl1, tyl2), TyUnion (tyr1, tyr2) ->
        check_type_eq i tyl1 tyr1 >> check_type_eq i tyl2 tyr2 
    | TyTensor (tyl1, tyl2), TyTensor (tyr1, tyr2) ->
        check_type_eq i tyl1 tyr1 >> check_type_eq i tyl2 tyr2
    | _, _ -> fail i @@ TypeMismatch (ty_1, ty_2)

  let check_maybe_type_eq (i : info) (ty_1 : ty option) (ty_2 : ty) :
      unit checker =
    match ty_1 with
    | Some ty -> check_type_eq i ty ty_2 >> return ()
    | None -> return ()

  (* Checks for types of different shapes *)
  let check_tensor_shape i ty =
    match ty with
    | TyTensor (ty1, ty2) -> return (ty1, ty2)
    | _ -> fail i @@ WrongShape (ty, "tensor")

  let check_union_shape i ty =
    match ty with
    | TyUnion (ty1, ty2) -> return (ty1, ty2)
    | _ -> fail i @@ WrongShape (ty, "union")

  (* Checks that a variable is fully discrete *)
  let rec check_disc_ty (i : info) (ty : ty) : unit checker =
    match ty with
    | TyPrim PrimDNum -> return ()
    | TyUnion (ty_1, ty_2) -> check_disc_ty i ty_1 >> check_disc_ty i ty_2
    | TyTensor (ty_1, ty_2) -> check_disc_ty i ty_1 >> check_disc_ty i ty_2
    | _ -> fail i @@ NotDiscrete ty

  (* Checks that variable has base numeric type *)
  let check_prim_num (i : info) (v : var_info) : unit checker =
    get_var_ty v >>= fun ty ->
    match ty with
    | TyPrim PrimNum -> return ()
    | _ -> fail i @@ WrongType (ty, TyPrim PrimNum)

  let check_prim_dnum (i : info) (v : var_info) : unit checker =
    get_dvar_ty v >>= fun ty ->
    match ty with
    | TyPrim PrimDNum -> return ()
    | _ -> fail i @@ WrongType (ty, TyPrim PrimNum)
end

open TypeSub

(* Extend the context with a value binding and run a computation. The
   computation is assumed to produce a list of results, one for each
   variable in the extended context. That list is destructed, and the
   result corresponding to the new variable is returned separately for
   convenience *)
let with_extended_ctx (i : info) (v : string) (ty : ty)
    (m : ('a * 'b list) checker) : ('a * 'b * 'b list) checker =
  with_new_ctx (extend_var v ty) m >>= fun (res, res_ext_ctx) ->
  match res_ext_ctx with
  | res_v :: res_ctx -> return (res, res_v, res_ctx)
  | [] ->
      fail i
      @@ Internal
           "Computation on extended context didn't produce enough results"

(* Extends the discrete context with one variable *)
let with_extended_dctx (v : string) (ty : ty) (m : ('a * 'b list) checker) :
    ('a * 'b list) checker =
  with_new_dctx (fun dctx -> extend_var v ty dctx) m

(* Similar to the one above, but with two variables. vx has index 1 in
   the extended context, while vy has index 0. The order of the
   returned results matches those of the arguments *)
let with_extended_ctx_2 (i : info) (vx : string) (tyx : ty) (vy : string)
    (tyy : ty) (m : ('a * 'b list) checker) : ('a * 'b * 'b * 'b list) checker =
  with_new_ctx (fun ctx -> extend_var vy tyy (extend_var vx tyx ctx)) m
  >>= fun (res, res_ext_ctx) ->
  match res_ext_ctx with
  | res_y :: res_x :: res_ctx -> return (res, res_x, res_y, res_ctx)
  | _ ->
      fail i
      @@ Internal
           "Computation on extended context didn't produce enough results"

(* Extends the discrete context with two variables *)
let with_extended_dctx_2 (vx : string) (tyx : ty) (vy : string) (tyy : ty)
    (m : ('a * 'b list) checker) : ('a * 'b list) checker =
  with_new_dctx (fun dctx -> extend_var vy tyy (extend_var vx tyx dctx)) m

(* Checks that two contexts are disjoint for the purpose of a let-binding or similar *)
let check_disjoint_let i (x : string) (ctx1 : obe list) (ctx2 : obe list) :
    unit checker =
  match check_disjoint ctx1 ctx2 with
  | Some _ -> fail i @@ LetNotLinear x
  | None -> return ()

let check_disjoint_let_2 i (x : string) (y : string) (ctx1 : obe list)
    (ctx2 : obe list) : unit checker =
  match check_disjoint ctx1 ctx2 with
  | Some _ -> fail i @@ LetNotLinear2 (x, y)
  | None -> return ()

(* Checks that two contexts are disjoint for the purpose of a product *)
let check_disjoint_prod i (ctx1 : obe list) (ctx2 : obe list) : unit checker =
  match check_disjoint ctx1 ctx2 with
  | Some _ -> fail i @@ ProdNotLinear
  | None -> return ()

let check_none i (x : string) (be : obe) =
  match be with Some _ -> return () | None -> fail i @@ NonZeroErr x

(* Given a term t and a context ctx for that term, check whether t is
   typeable under ctx, returning a type for t, and a list of errors for ctx. 
   Raises an error if it detects that no typing is possible *)
let rec type_of (t : term) : (ty * obe list) checker =
  ty_debug (tm_info t) "[%3d] --> type_of: @[%a@]" !ty_seq Print.pp_term t;
  incr ty_seq;

  (match t with
  (* Variables *)
  | TmVar (_i, x) ->
      get_ctx_length >>= fun len ->
      get_var_ty x >>= fun ty_x -> return (ty_x, singleton len x be_zero)
  | TmDVar (_i, x) ->
      get_ctx_length >>= fun len ->
      get_dvar_ty x >>= fun ty_x -> return (ty_x, nones len)
  | TmDisc (_i, tm_e) ->
      type_of tm_e >>= fun (ty_e, ctx_e) -> return (disc ty_e, ctx_e)
  (* Primitive terms *)
  | TmPrim (_, _pt) ->
      get_ctx_length >>= fun len -> return (type_of_prim, nones len)
  (* let (x : oty_x) = e in f *)
  | TmLet (i, x, oty_x, tm_e, tm_f) ->
      type_of tm_e >>= fun (ty_e, ctx_e) ->
      check_maybe_type_eq i oty_x ty_e
      >> with_extended_ctx i x.b_name ty_e (type_of tm_f)
      >>= fun (ty_f, be_x, ctx_f) ->
      check_disjoint_let i x.b_name ctx_e ctx_f
      >> return (ty_f, union_ctx (shift_err be_x ctx_e) ctx_f)
  (* dlet (z : oty_z) = e in f *)
  | TmDLet (i, z, oty_z, tm_e, tm_f) ->
      type_of tm_e >>= fun (ty_e, ctx_e) ->
      check_maybe_type_eq i oty_z ty_e
      >> check_disc_ty i ty_e
      >> with_extended_dctx z.b_name ty_e (type_of tm_f)
      >>= fun (ty_f, ctx_f) ->
      check_disjoint_let i z.b_name ctx_e ctx_f
      >> return (ty_f, union_ctx ctx_e ctx_f)
  (* bind (x : oty_x) = e in f *)
  | TmBind (i, x, oty_x, tm_e, tm_f) ->
      type_of tm_e >>= fun (ty_e, ctx_e) ->
      check_maybe_type_eq i (disc_obe oty_x) ty_e
      >> check_disc_ty i ty_e
      >> with_extended_ctx i x.b_name (linear ty_e) (type_of tm_f)
      >>= fun (ty_f, si_x, ctx_f) ->
      check_disc_ty i ty_f >> check_none i x.b_name si_x
      >> check_disjoint_let i x.b_name ctx_e ctx_f
      >> return (ty_f, union_ctx ctx_e ctx_f)
  (* Tensor product*)
  | TmTens (i, tm_e, tm_f) ->
      type_of tm_e >>= fun (ty_e, ctx_e) ->
      type_of tm_f >>= fun (ty_f, ctx_f) ->
      check_disjoint_prod i ctx_e ctx_f
      >> return (TyTensor (ty_e, ty_f), union_ctx ctx_e ctx_f)
  (* let (x, y) = e in f *)
  | TmTensDest (i, x, y, tm_e, tm_f) ->
      type_of tm_e >>= fun (ty_e, ctx_e) ->
      check_tensor_shape i ty_e >>= fun (ty_x, ty_y) ->
      with_extended_ctx_2 i x.b_name ty_x y.b_name ty_y (type_of tm_f)
      >>= fun (ty_f, be_x, be_y, ctx_f) ->
      check_disjoint_let_2 i x.b_name y.b_name ctx_e ctx_f
      >>
      let be = lub_obe be_x be_y in
      return (ty_f, union_ctx (shift_err be ctx_e) ctx_f)
  (* dlet (x, y) = e in f *)
  | TmTensDDest (i, x, y, tm_e, tm_f) ->
      type_of tm_e >>= fun (ty_e, ctx_e) ->
      check_disc_ty i ty_e >> check_tensor_shape i ty_e >>= fun (ty_x, ty_y) ->
      with_extended_dctx_2 x.b_name ty_x y.b_name ty_y (type_of tm_f)
      >>= fun (ty_f, ctx_f) ->
      check_disjoint_let_2 i x.b_name y.b_name ctx_e ctx_f
      >> return (ty_f, union_ctx ctx_e ctx_f)
  | TmInl (_i, ty_r, tm_l) ->
      type_of tm_l >>= fun (ty, ctx) -> return (TyUnion (ty, ty_r), ctx)
  | TmInr (_i, ty_l, tm_r) ->
      type_of tm_r >>= fun (ty, ctx) -> return (TyUnion (ty_l, ty), ctx)
  (* case v of (x.e_l | y.f_r) *)
  | TmUnionCase (i, v, b_x, e_l, b_y, f_r) ->
      type_of v >>= fun (ty_v, ctx_v) ->
      check_union_shape i ty_v >>= fun (ty1, ty2) ->
      with_extended_ctx i b_x.b_name ty1 (type_of e_l)
      >>= fun (tyl, si_x, ctx_l) ->
      with_extended_ctx i b_y.b_name ty2 (type_of f_r)
      >>= fun (tyr, si_y, ctx_r) ->
      (* check that e_l and f_r have the same type *)
      check_type_eq i tyl tyr >>
      (* check that domains are disjoint *)
      check_disjoint_let i b_x.b_name ctx_v ctx_l
      >> check_disjoint_let i b_y.b_name ctx_v ctx_r
      >> let be = lub_obe si_x si_y in
      (* non-disjoint union of left and right contexts *)
      let ctx_union = union_ctx ctx_l ctx_r in
      return (tyl, union_ctx (shift_err be ctx_v) ctx_union)
  (* Ops *)
  | TmAdd (i, x, y) ->
      check_prim_num i x >> check_prim_num i y >> get_ctx_length >>= fun len ->
      return (TyPrim PrimNum, binop_ctx len x y be_one be_one)
  | TmSub (i, x, y) ->
      check_prim_num i x >> check_prim_num i y >> get_ctx_length >>= fun len ->
      return (TyPrim PrimNum, binop_ctx len x y be_one be_one)
  | TmMul (i, x, y) ->
      check_prim_num i x >> check_prim_num i y >> get_ctx_length >>= fun len ->
      return (TyPrim PrimNum, binop_ctx len x y be_hlf be_hlf)
  | TmDiv (i, x, y) ->
      check_prim_num i x >> check_prim_num i y >> get_ctx_length >>= fun len ->
      return
        ( TyUnion (TyPrim PrimNum, TyPrim PrimUnit),
          binop_ctx len x y be_hlf be_hlf )
  | TmDMul (i, z, x) ->
      check_prim_dnum i z >> check_prim_num i x >> get_ctx_length >>= fun len ->
      return (TyPrim PrimNum, singleton len x be_one))
  >>= fun (ty, sis) ->
  decr ty_seq;
  ty_debug (tm_info t) "[%3d] <-- type_of: @[%a@] with type @[%a@]" !ty_seq
    Print.pp_term t Print.pp_type ty;
  return (ty, sis)

let pp_tyerr ppf s =
  match s with
  | LetNotLinear v ->
      fprintf ppf "[%3d] %s uses a variable that is used again later" !ty_seq v
  | LetNotLinear2 (v1, v2) ->
      fprintf ppf "[%3d] (%s, %s) uses a variable that is used again later"
        !ty_seq v1 v2
  | ProdNotLinear ->
      fprintf ppf "[%3d] Product components have non-disjoint contexts" !ty_seq
  | TypeMismatch (ty1, ty2) ->
      fprintf ppf "[%3d] Cannot unify %a with %a" !ty_seq pp_type ty1 pp_type
        ty2
  | WrongType (ty1, ty2) ->
      fprintf ppf "[%3d] Expected %a to be %a" !ty_seq pp_type ty1 pp_type ty2
  | WrongShape (ty, sh) ->
      fprintf ppf "[%3d] Type %a has wrong shape, expected %s type" !ty_seq
        pp_type ty sh
  | NotDiscrete ty ->
      fprintf ppf "[%3d] Expected %a to be discrete" !ty_seq pp_type ty
  | NonZeroErr v -> fprintf ppf "[%3d] Expected %s to have zero error" !ty_seq v
  | Internal s -> fprintf ppf "[%3d] Internal error: %s" !ty_seq s

(* Equivalent to run *)
let get_type program context dcontext =
  match type_of program context dcontext with
  | Right (ty, sis) -> (ty, sis)
  | Left e -> ty_error_pp e.i pp_tyerr e.v
