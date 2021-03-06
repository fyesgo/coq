(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *   INRIA, CNRS and contributors - Copyright 1999-2018       *)
(* <O___,, *       (see CREDITS file for the list of authors)           *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

open Names
open Constr
open Univ
open Declarations

(** Unsafe environments. We define here a datatype for environments.
   Since typing is not yet defined, it is not possible to check the
   informations added in environments, and that is why we speak here
   of ``unsafe'' environments. *)

(** Environments have the following components:
   - a context for de Bruijn variables
   - a context for de Bruijn variables vm values
   - a context for section variables and goal assumptions
   - a context for section variables and goal assumptions vm values
   - a context for global constants and axioms
   - a context for inductive definitions
   - a set of universe constraints
   - a flag telling if Set is, can be, or cannot be set impredicative *)

type lazy_val

val build_lazy_val : lazy_val -> (Vmvalues.values * Id.Set.t) -> unit
val force_lazy_val : lazy_val -> (Vmvalues.values * Id.Set.t) option
val dummy_lazy_val : unit -> lazy_val

(** Linking information for the native compiler *)
type link_info =
  | Linked of string
  | LinkedInteractive of string
  | NotLinked

type key = int CEphemeron.key option ref

type constant_key = constant_body * (link_info ref * key)

type mind_key = mutual_inductive_body * link_info ref

type globals = {
  env_constants : constant_key Cmap_env.t;
  env_projections : projection_body Cmap_env.t;
  env_inductives : mind_key Mindmap_env.t;
  env_modules : module_body MPmap.t;
  env_modtypes : module_type_body MPmap.t
}

type stratification = {
  env_universes : UGraph.t;
  env_engagement : engagement
}

type named_context_val = private {
  env_named_ctx : Context.Named.t;
  env_named_map : (Context.Named.Declaration.t * lazy_val) Id.Map.t;
}

type rel_context_val = private {
  env_rel_ctx : Context.Rel.t;
  env_rel_map : (Context.Rel.Declaration.t * lazy_val) Range.t;
}

type env = private {
  env_globals       : globals;           (* globals = constants + inductive types + modules + module-types *)
  env_named_context : named_context_val; (* section variables *)
  env_rel_context   : rel_context_val;
  env_nb_rel        : int;
  env_stratification : stratification;
  env_typing_flags  : typing_flags;
  retroknowledge : Retroknowledge.retroknowledge;
  indirect_pterms : Opaqueproof.opaquetab;
}

val oracle : env -> Conv_oracle.oracle
val set_oracle : env -> Conv_oracle.oracle -> env

val eq_named_context_val : named_context_val -> named_context_val -> bool

val empty_env : env

val universes     : env -> UGraph.t
val rel_context   : env -> Context.Rel.t
val named_context : env -> Context.Named.t
val named_context_val : env -> named_context_val

val opaque_tables : env -> Opaqueproof.opaquetab
val set_opaque_tables : env -> Opaqueproof.opaquetab -> env


val engagement    : env -> engagement
val typing_flags    : env -> typing_flags
val is_impredicative_set : env -> bool
val type_in_type : env -> bool
val deactivated_guard : env -> bool

(** is the local context empty *)
val empty_context : env -> bool

(** {5 Context of de Bruijn variables ([rel_context]) } *)

val nb_rel           : env -> int
val push_rel         : Context.Rel.Declaration.t -> env -> env
val push_rel_context : Context.Rel.t -> env -> env
val push_rec_types   : rec_declaration -> env -> env

(** Looks up in the context of local vars referred by indice ([rel_context]) 
   raises [Not_found] if the index points out of the context *)
val lookup_rel    : int -> env -> Context.Rel.Declaration.t
val lookup_rel_val : int -> env -> lazy_val
val evaluable_rel : int -> env -> bool
val env_of_rel     : int -> env -> env

(** {6 Recurrence on [rel_context] } *)

val fold_rel_context :
  (env -> Context.Rel.Declaration.t -> 'a -> 'a) -> env -> init:'a -> 'a

(** {5 Context of variables (section variables and goal assumptions) } *)

val named_context_of_val : named_context_val -> Context.Named.t
val val_of_named_context : Context.Named.t -> named_context_val
val empty_named_context_val : named_context_val
val ids_of_named_context_val : named_context_val -> Id.Set.t


(** [map_named_val f ctxt] apply [f] to the body and the type of
   each declarations.
   *** /!\ ***   [f t] should be convertible with t *)
val map_named_val :
   (constr -> constr) -> named_context_val -> named_context_val

val push_named : Context.Named.Declaration.t -> env -> env
val push_named_context : Context.Named.t -> env -> env
val push_named_context_val  :
    Context.Named.Declaration.t -> named_context_val -> named_context_val



(** Looks up in the context of local vars referred by names ([named_context]) 
   raises [Not_found] if the Id.t is not found *)

val lookup_named     : variable -> env -> Context.Named.Declaration.t
val lookup_named_val : variable -> env -> lazy_val
val lookup_named_ctxt : variable -> named_context_val -> Context.Named.Declaration.t
val evaluable_named  : variable -> env -> bool
val named_type : variable -> env -> types
val named_body : variable -> env -> constr option

(** {6 Recurrence on [named_context]: older declarations processed first } *)

val fold_named_context :
  (env -> Context.Named.Declaration.t -> 'a -> 'a) -> env -> init:'a -> 'a

val set_universes : env -> UGraph.t -> env

(** Recurrence on [named_context] starting from younger decl *)
val fold_named_context_reverse :
  ('a -> Context.Named.Declaration.t -> 'a) -> init:'a -> env -> 'a

(** This forgets named and rel contexts *)
val reset_context : env -> env

(** This forgets rel context and sets a new named context *)
val reset_with_named_context : named_context_val -> env -> env

(** This removes the [n] last declarations from the rel context *)
val pop_rel_context : int -> env -> env

(** {5 Global constants }
  {6 Add entries to global environment } *)

val add_constant : Constant.t -> constant_body -> env -> env
val add_constant_key : Constant.t -> constant_body -> link_info ->
  env -> env
val lookup_constant_key :  Constant.t -> env -> constant_key

(** Looks up in the context of global constant names 
   raises [Not_found] if the required path is not found *)
val lookup_constant    : Constant.t -> env -> constant_body
val evaluable_constant : Constant.t -> env -> bool

(** New-style polymorphism *)
val polymorphic_constant  : Constant.t -> env -> bool
val polymorphic_pconstant : pconstant -> env -> bool
val type_in_type_constant : Constant.t -> env -> bool

(** {6 ... } *)
(** [constant_value env c] raises [NotEvaluableConst Opaque] if
   [c] is opaque and [NotEvaluableConst NoBody] if it has no
   body and [NotEvaluableConst IsProj] if [c] is a projection 
   and [Not_found] if it does not exist in [env] *)

type const_evaluation_result = NoBody | Opaque
exception NotEvaluableConst of const_evaluation_result

val constant_type : env -> Constant.t puniverses -> types constrained

val constant_value_and_type : env -> Constant.t puniverses -> 
  constr option * types * Univ.Constraint.t
(** The universe context associated to the constant, empty if not 
    polymorphic *)
val constant_context : env -> Constant.t -> Univ.AUContext.t

(* These functions should be called under the invariant that [env] 
   already contains the constraints corresponding to the constant 
   application. *)
val constant_value_in : env -> Constant.t puniverses -> constr
val constant_type_in : env -> Constant.t puniverses -> types
val constant_opt_value_in : env -> Constant.t puniverses -> constr option

(** {6 Primitive projections} *)

val lookup_projection    : Names.Projection.t -> env -> projection_body
val is_projection : Constant.t -> env -> bool

(** {5 Inductive types } *)
val lookup_mind_key : MutInd.t -> env -> mind_key
val add_mind_key : MutInd.t -> mind_key -> env -> env
val add_mind : MutInd.t -> mutual_inductive_body -> env -> env

(** Looks up in the context of global inductive names 
   raises [Not_found] if the required path is not found *)
val lookup_mind : MutInd.t -> env -> mutual_inductive_body

(** New-style polymorphism *)
val polymorphic_ind  : inductive -> env -> bool
val polymorphic_pind : pinductive -> env -> bool
val type_in_type_ind : inductive -> env -> bool

(** Old-style polymorphism *)
val template_polymorphic_ind : inductive -> env -> bool
val template_polymorphic_pind : pinductive -> env -> bool

(** {5 Modules } *)

val add_modtype : module_type_body -> env -> env

(** [shallow_add_module] does not add module components *)
val shallow_add_module : module_body -> env -> env

val lookup_module : ModPath.t -> env -> module_body
val lookup_modtype : ModPath.t -> env -> module_type_body

(** {5 Universe constraints } *)

(** Add universe constraints to the environment.
    @raise UniverseInconsistency .
*)
val add_constraints : Univ.Constraint.t -> env -> env

(** Check constraints are satifiable in the environment. *)
val check_constraints : Univ.Constraint.t -> env -> bool
val push_context : ?strict:bool -> Univ.UContext.t -> env -> env
val push_context_set : ?strict:bool -> Univ.ContextSet.t -> env -> env
val push_constraints_to_env : 'a Univ.constrained -> env -> env

val set_engagement : engagement -> env -> env
val set_typing_flags : typing_flags -> env -> env

(** {6 Sets of referred section variables }
   [global_vars_set env c] returns the list of [id]'s occurring either
   directly as [Var id] in [c] or indirectly as a section variable
   dependent in a global reference occurring in [c] *)

val global_vars_set : env -> constr -> Id.Set.t

(** the constr must be a global reference *)
val vars_of_global : env -> constr -> Id.Set.t

(** closure of the input id set w.r.t. dependency *)
val really_needed : env -> Id.Set.t -> Id.Set.t

(** like [really_needed] but computes a well ordered named context *)
val keep_hyps : env -> Id.Set.t -> Context.Named.t

(** {5 Unsafe judgments. }
    We introduce here the pre-type of judgments, which is
  actually only a datatype to store a term with its type and the type of its
  type. *)

type ('constr, 'types) punsafe_judgment = {
  uj_val : 'constr;
  uj_type : 'types }

type unsafe_judgment = (constr, types) punsafe_judgment

val make_judge : 'constr -> 'types -> ('constr, 'types) punsafe_judgment
val j_val  : ('constr, 'types) punsafe_judgment -> 'constr
val j_type : ('constr, 'types) punsafe_judgment -> 'types

type 'types punsafe_type_judgment = {
  utj_val : 'types;
  utj_type : Sorts.t }

type unsafe_type_judgment = types punsafe_type_judgment

exception Hyp_not_found

(** [apply_to_hyp sign id f] split [sign] into [tail::(id,_,_)::head] and
   return [tail::(f head (id,_,_) (rev tail))::head].
   the value associated to id should not change *)
val apply_to_hyp : named_context_val -> variable ->
  (Context.Named.t -> Context.Named.Declaration.t -> Context.Named.t -> Context.Named.Declaration.t) ->
    named_context_val

val remove_hyps : Id.Set.t -> (Context.Named.Declaration.t -> Context.Named.Declaration.t) -> (lazy_val -> lazy_val) -> named_context_val -> named_context_val



open Retroknowledge
(** functions manipulating the retroknowledge 
    @author spiwack *)
val retroknowledge : (retroknowledge->'a) -> env -> 'a

val registered : env -> field -> bool

val register : env -> field -> Retroknowledge.entry -> env

(** Native compiler *)
val no_link_info : link_info
