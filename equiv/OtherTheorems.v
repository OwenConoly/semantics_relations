Require Import Coq.Lists.List.
Require Import coqutil.Tactics.fwd.
Require Import Coq.Logic.ClassicalFacts.
Require Import Coq.Logic.ChoiceFacts.
Require Import equiv.EquivProof. (*just for a tactic or two*)

Section ShortTheorems.
  Context (L B : Type).
  Context (B_inhabited : B).

  (*note that (list event) is the sort of leakage trace discussed in the paper.*)
  Inductive event :=
  | leak (val : L)
  | branch (val : B).

  Inductive qevent : Type :=
  | qleak (val : L)
  | qbranch
  | qend.

  Definition q (e : event) : qevent :=
    match e with
    | leak l => qleak l
    | branch b => qbranch
    end.

  (*Defn 4.1 of paper*)
  Definition predicts' (pred : list event -> qevent) (k : list event) :=
    (forall k1 x k2, k = k1 ++ leak x :: k2 -> pred k1 = qleak x)/\
      (forall k1 x k2, k = k1 ++ branch x :: k2 -> pred k1 = qbranch) /\
      pred k = qend.

  (*an equivalent inductive definition*)
  Inductive predicts : (list event -> qevent) -> list event -> Prop :=
  | predicts_nil f : f nil = qend -> predicts f nil
  | predicts_cons f e k : f nil = q e -> predicts (fun k_ => f (e :: k_)) k -> predicts f (e :: k).

  (*Definition 2.3 of the paper*)
  Definition compat' (oracle : list event -> B) (k : list event) :=
    forall k1 x k2, k = k1 ++ branch x :: k2 -> oracle k1 = x.

  (*an equivalent inductive definition*)
  Inductive compat : (list event -> B) -> list event -> Prop :=
  | compat_nil o : compat o nil
  | compat_cons_branch o k b : o nil = b -> compat (fun k_ => o (branch b :: k_)) k -> compat o (branch b :: k)
  | compat_cons_leak o k l : compat (fun k_ => o (leak l :: k_)) k -> compat o (leak l :: k).
  
  Lemma predicts'_iff_predicts pred k : predicts' pred k <-> predicts pred k.
  Proof.
    split.
    - revert pred.
      induction k as [|e k']; [|destruct e as [l|b]]; intros pred H; unfold predicts' in H; fwd.
      + constructor. assumption.
      + constructor.
        -- eapply Hp0. trace_alignment.
        -- eapply IHk'. cbv [predicts']. split; [|split].
           ++ intros. subst. eapply Hp0. trace_alignment.
           ++ intros. subst. eapply Hp1. trace_alignment.
           ++ assumption.
      + constructor.
        -- eapply Hp1. trace_alignment.
        -- eapply IHk'. cbv [predicts']. split; [|split].
           ++ intros. subst. eapply Hp0. trace_alignment.
           ++ intros. subst. eapply Hp1. trace_alignment.
           ++ assumption.
    - intros H. induction H.
      + split; [|split].
        -- intros. destruct k1; simpl in H0; congruence.
        -- intros. destruct k1; simpl in H0; congruence.
        -- assumption.
      + destruct IHpredicts as [H1 [H2 H3]]. split; [|split].
        -- intros. destruct k1; inversion H4; subst; simpl in *; try congruence.
           eapply H1. trace_alignment.
        -- intros. destruct k1; inversion H4; subst; simpl in *; try congruence.
           eapply H2. trace_alignment.
        -- assumption.
  Qed.

  Lemma compat'_iff_compat o k : compat' o k <-> compat o k.
  Proof.
    split.
    - intros H. revert o H. induction k; intros o H.
      + constructor.
      + destruct a.
        -- constructor. apply IHk. cbv [compat']. intros. subst. eapply H. trace_alignment.
        -- constructor.
           ++ eapply H. trace_alignment.
           ++ apply IHk. cbv [compat']. intros. subst. eapply H. trace_alignment.
    - intros H. cbv [compat']. induction H; intros.
      + destruct k1; simpl in H; congruence.
      + destruct k1; simpl in H1; try congruence. inversion H1. subst.
        eapply IHcompat. trace_alignment.
      + destruct k1; simpl in H0; try congruence. inversion H0. subst.
        eapply IHcompat. trace_alignment.
  Qed.

  (*as in section C.1 of the paper*)
  Inductive trace_tree : Type :=
  | tree_leaf
  | tree_leak (l : L) (rest : trace_tree)
  | tree_branch (rest : B -> trace_tree).

  (*Definition C.1 of the paper*)
  Inductive path : trace_tree -> list event -> Prop :=
  | nil_path : path tree_leaf nil
  | leak_path x k tree : path tree k -> path (tree_leak x tree) (leak x :: k)
  | branch_path k f x : path (f x) k -> path (tree_branch f) (branch x :: k).

  Fixpoint predictor_of_trace_tree (tree : trace_tree) : (list event -> qevent) :=
    fun k =>
      match tree, k with
      | tree_leaf, nil => qend
      | tree_leak l tree', nil => qleak l
      | tree_branch tree', nil => qbranch
      | tree_leak l1 tree', leak l2 :: k' => predictor_of_trace_tree tree' k'
      | tree_branch tree', branch b :: k' => predictor_of_trace_tree (tree' b) k'
      | _, _ => (*input is garbage, return whatever*) qend
      end.

  (*Theorem C.3 of the paper*)
  Theorem trace_trees_are_predictors :
    forall tree, exists pred, forall k,
      path tree k <-> predicts' pred k.
  Proof.
    intros. exists (predictor_of_trace_tree tree). intros. rewrite predicts'_iff_predicts.
    split; intros H.
    - induction H.
      + constructor. reflexivity.
      + constructor; [reflexivity|]. assumption.
      + constructor; [reflexivity|]. assumption.
    - revert k H. induction tree; intros k H'.
      + simpl in H'. inversion H'; simpl in *; subst.
        -- constructor.
        -- destruct e; simpl in H; congruence.
      + destruct k as [|e k'].
        { simpl in H'. inversion H'; subst. congruence. }
        destruct e.
        -- inversion H'. subst. simpl in H2. inversion H2. subst. constructor.
           apply IHtree. simpl in H3. apply H3.
        -- inversion H'. subst. simpl in H2. inversion H2.
      + destruct k as [|e k'].
        { simpl in H'. inversion H'; subst. congruence. }
        destruct e.
        -- inversion H'. subst. simpl in H3. inversion H3.
        -- inversion H'. subst. simpl in H3. inversion H3. subst. constructor.
           apply H. simpl in H4. apply H4.
  Qed.

  Fixpoint trace_of_predictor_and_oracle pred o fuel : option (list event) :=
    match fuel with
    | O => None
    | S fuel' =>
        match pred nil with
        | qend => Some nil
        | qleak l => option_map (cons (leak l)) (trace_of_predictor_and_oracle
                                                  (fun k_ => pred (leak l :: k_))
                                                  (fun k_ => o (leak l :: k_))
                                                  fuel')
                               
        | qbranch => option_map (cons (branch (o nil))) (trace_of_predictor_and_oracle
                                                          (fun k_ => pred (branch (o nil) :: k_))
                                                          (fun k_ => o (branch (o nil) :: k_))
                                                          fuel')
                               
        end
    end.

  (*Theorem 4.3 of the paper*)
  Lemma predictor_plus_oracle_equals_trace :
    excluded_middle ->
    FunctionalChoice_on ((list event -> B) * (list event -> qevent)) (option (list event)) ->
    exists trace,
    forall o pred k,
      compat o k ->
      (predicts pred k <-> Some k = trace (o, pred)).
  Proof.
    intros em choice. cbv [FunctionalChoice_on] in choice.
    specialize (choice (fun o_pred tr => let '(o, pred) := o_pred in forall k, compat o k -> predicts pred k <-> Some k = tr)).
    destruct choice as [trace choice].
    2: { exists trace. intros. specialize (choice (o, pred) k H). apply choice. }
    intros [o pred]. destruct (em (exists fuel, trace_of_predictor_and_oracle pred o fuel <> None)) as [H | H].
    - destruct H as [fuel H]. exists (match trace_of_predictor_and_oracle pred o fuel with
                                 | Some k => Some k
                                 | None => Some nil
                                 end).
      intros. destruct (trace_of_predictor_and_oracle pred o fuel) eqn:E; try congruence.
      clear H. revert l k pred o H0 E. induction fuel.
      + intros. simpl in E. congruence.
      + intros. simpl in E. split.
        -- intros H. destruct k as [|e k'].
           ++ inversion H. subst. rewrite H1 in E. inversion E. subst. reflexivity.
           ++ inversion H. subst. rewrite H4 in E. destruct e; simpl in E.
              --- destruct (trace_of_predictor_and_oracle _ _ _) eqn:E'; simpl in E; try congruence.
                  inversion E. subst. f_equal. inversion H0. subst. f_equal.
                  enough (Some k' = Some l0) by congruence. eapply IHfuel; eassumption.
              --- destruct (trace_of_predictor_and_oracle _ _ _) eqn:E'; simpl in E; try congruence.
                  inversion E. subst. inversion H0. subst. f_equal. f_equal.
                  enough (Some k' = Some l0) by congruence. eapply IHfuel; eassumption.
        -- intros H. inversion H. subst. clear H. destruct l as [|e l].
           ++ constructor. destruct (pred nil).
              --- destruct (trace_of_predictor_and_oracle _ _ _) eqn:E'; simpl in E; congruence.
              --- destruct (trace_of_predictor_and_oracle _ _ _) eqn:E'; simpl in E; congruence.
              --- reflexivity.
           ++ destruct (pred nil) eqn:E''.
              --- destruct (trace_of_predictor_and_oracle _ _ _) eqn:E'; simpl in E; try congruence.
                  inversion E. subst. inversion H0. subst. constructor.
                  +++ assumption.
                  +++ eapply IHfuel; try eassumption. reflexivity.
              --- destruct (trace_of_predictor_and_oracle _ _ _) eqn:E'; simpl in E; try congruence.
                  inversion E. subst. inversion H0. subst. constructor.
                  +++ assumption.
                  +++ eapply IHfuel; try eassumption. reflexivity.
              --- inversion E.
    - exists None. intros. split; intros H1; try congruence. exfalso. apply H. clear H.
      revert o pred H0 H1. induction k as [|e k'].
      + intros. exists (S O). simpl. inversion H1. rewrite H. congruence.
      + intros. destruct e.
        -- inversion H0. inversion H1. subst. specialize IHk' with (1 := H3) (2 := H9).
           destruct IHk' as [fuel IHk']. exists (S fuel). simpl. rewrite H8. simpl.
           destruct (trace_of_predictor_and_oracle _ _ _); try congruence. simpl.
           congruence.
        -- inversion H0. inversion H1. subst. specialize IHk' with (1 := H5) (2 := H10).
           destruct IHk' as [fuel IHk']. exists (S fuel). simpl. rewrite H9. simpl.
           destruct (trace_of_predictor_and_oracle _ _ _); try congruence. simpl. congruence.
  Qed.

  Fixpoint oracle_of_trace (k k_ : list event) : B :=
    match k, k_ with
    | branch b :: k', nil => b
    | _ :: k', _ :: k_' => oracle_of_trace k' k_'
    | _, _ => B_inhabited
    end.

  Lemma oracle_of_trace_works k :
    compat (oracle_of_trace k) k.
  Proof.
   induction k.
    - constructor.
    - destruct a; constructor; assumption || reflexivity.
  Qed.
  
  Lemma compat_exists :
    forall k, exists o, compat o k.
  Proof.
    intros k. exists (oracle_of_trace k). induction k.
    - constructor.
    - destruct a; constructor; assumption || reflexivity.
  Qed.

  (*Corollary 4.4 of the paper*)
  Theorem predictors_to_oracles {T T' : Type} :
    excluded_middle ->
    FunctionalChoice_on ((list event -> B) * (list event -> qevent)) (option (list event)) ->
    forall pred (g : T -> T'), exists f, forall k t,
      predicts (pred (g t)) k <-> (forall o, (compat o k -> Some k = f o (g t))).
  Proof.
    intros. specialize predictor_plus_oracle_equals_trace with (1 := H) (2 := H0).
    clear H H0. intros [trace H]. exists (fun o gt => trace (o, pred gt)).
    intros. split. 1: intros; apply H; assumption. intros.
    specialize (compat_exists k). intros [o Ho]. specialize (H0 o Ho). rewrite H; eassumption.
  Qed.

  Fixpoint p' (p1 : list event -> qevent) (p2 : list event -> list event -> qevent) (k : list event) :=
    match (p1 nil) with
    | qend => p2 nil k
    | _ => match k with
          | nil => (p1 nil)
          | x :: k' => p' (fun kk => p1 (x :: kk)) (fun kk => p2 (x :: kk)) k'
          end
    end.

  Fixpoint p  (p1 : list event -> qevent) (p2 : list event -> list event -> qevent) (k : list event) :=
    match k with
    | nil => match (p1 nil) with
            | qend => p2 nil k
            | _ => (p1 nil)
            end
    | x :: k' => match (p1 nil) with
               | qend => p2 nil k
               | _ => p (fun kk => p1 (x :: kk)) (fun kk => p2 (x :: kk)) k'
               end
    end.

  (*Lemma D.1 of the paper*)
  Lemma append_predictors p1 p2 : exists p,
    forall k1 k2, predicts p1 k1 -> predicts (p2 k1) k2 -> predicts p (k1 ++ k2).
  Proof.
    exists (p p1 p2). intros k1. revert p1 p2. induction k1; intros.
    - simpl. inversion H. subst. destruct k2; simpl.
      + inversion H0. subst. constructor. simpl. rewrite H1. assumption.
      + inversion H0. subst. constructor.
        -- simpl. rewrite H1. assumption.
        -- simpl. rewrite H1. assumption.
    - simpl. inversion H. subst. clear H.
      constructor.
      -- simpl. rewrite H4. destruct a; reflexivity.
      -- simpl. rewrite H4. destruct a.
         ++ simpl. apply IHk1. 1: assumption. assumption.
         ++ simpl. apply IHk1. 1: assumption. assumption.
  Qed.
  (*forall A k, prefix k f(A) -> forall B, compat B k -> prefix k f(B)*)

  Definition prefix {A: Type} (k1 k : list A) :=
    exists k2, k = k1 ++ k2.

  Print predicts.
  Fixpoint get_next (part whole : list event) : qevent :=
    match part, whole with
    | nil, leak x :: _ => qleak x
    | nil, branch _ :: _ => qbranch
    | nil, nil => qend
    | _ :: part', _ :: whole' => get_next part' whole'
    | _ :: _, nil => qend (*garbage*)
    end.
  
  Definition predictor_of_fun (f : (list event -> B) -> list event) (k : list event) : qevent :=
    let full_trace := f (oracle_of_trace k) in
    get_next k full_trace.

  Lemma both_prefixes {A : Type} (l1 l2 : list A) :
    prefix l1 l2 ->
    prefix l2 l1 ->
    l1 = l2.
  Proof.
    intros [l2' H1] [l1' H2].
    replace l1 with (l1 ++ nil) in H2 by apply app_nil_r.
    rewrite H1 in H2. rewrite <- app_assoc in H2.
    apply app_inv_head in H2. destruct l2'; inversion H2.
    rewrite H1. rewrite app_nil_r. reflexivity.
  Qed.

  Lemma prefix_refl {A : Type} (l : list A) :
    prefix l l.
  Proof. exists nil. symmetry. apply app_nil_r. Qed.
  
  Lemma full_thing_special_case f :
    (forall A k, prefix k (f A) -> forall B, compat B k -> prefix k (f B)) ->
    forall A B, compat B (f A) -> f B = f A.
  Proof.
    intros f_reasonable. intros o1 o2 Hcompat.
    epose proof (f_reasonable o1 (f o1) _ o2 _) as left.
    Unshelve. all: cycle 1.
    { apply prefix_refl. }
    { assumption. }
    destruct left as [nill left]. destruct nill.
    { rewrite app_nil_r in left. assumption. }
    epose proof (f_reasonable o2 (f o1 ++ e :: nil) _) as H'. Unshelve. all: cycle 1.
    { exists nill. rewrite <- app_assoc. simpl. assumption. }
    (*this is not true; suppose the program could 'look ahead' into the future to decide
      whether to take a branch.*)
  Abort.

  Lemma predictor_from_nowhere f :
    (forall A k, prefix k (f A) -> forall B, compat B k -> prefix k (f B)) ->
    (forall A B, compat B (f A) -> f B = f A) ->
    (forall A, compat A (f A)) ->
    exists pred,
    forall k,
      predicts pred k <-> (forall A, (compat A k -> k = f A)).
  Proof.
    intros f_step f_end f_compat.
    exists (predictor_of_fun f). intros. split.
    - intros Hpred A Hcompat. revert f f_step f_end f_compat Hpred.
      induction Hcompat; intros f f_step f_end f_compat Hpred.
      + inversion Hpred. clear Hpred. subst. cbv [predictor_of_fun] in H. simpl in H.
        destruct (f _) eqn:E; cycle 1. { destruct e; discriminate H. }
        epose proof (f_end _ o ltac:(rewrite E; econstructor)) as H'.
        rewrite H', E. reflexivity.
      + inversion Hpred. subst. clear Hpred. cbv [predictor_of_fun] in H3.
        simpl in H3. destruct (f (fun _ => B_inhabited)) eqn:E; try discriminate H3.
        destruct e; try discriminate H3. clear H3.
        epose proof (f_step o (branch (o nil) :: nil) _) as H.
        Unshelve. all: cycle 1.
        { rewrite E. exists l. reflexivity. }
        specialize (H o).
        
        destruct (f o) eqn:E'; [reflexivity|].
        epose proof (f_reasonable o (e :: nil) _) as H'.
        Unshelve. all: cycle 1.
        { rewrite E'. exists l. reflexivity. }           
        destruct e; exfalso.
        -- epose proof (H' (fun _ => B_inhabited) _) as H'.
           Unshelve. all: cycle 1.
           { constructor. constructor. }
           rewrite E in H'. destruct H' as [l' H']. simpl in H'. discriminate H'.
        -- epose proof (H' (fun _ => val) _) as H'.
           Unshelve. all: cycle 1.
           { constructor; [reflexivity|]. constructor. }
           epose proof (f_reasonable (fun _ => B_inhabited) nil _ (fun _ => val) _).
           Unshelve. all: cycle 1.
           { eexists. reflexivity. }
           { constructor. }
           
           
           { eexists. reflexivity. }
        eassert _ as blah. 2: specialize (f_reasoe  blah); clear blah.
        { eexists. reflexivity. }
        specialize (f_reasonable 
        eassert _ as blah. 2: specialize (f_reasonable o (e :: nil) blah); clear blah.
        { rewrite E'. exists l. reflexivity. }
        destruct e; exfalso.
        -- specialize (f_reasonable _ (oracle_of_trace_works _)).
        2: {
        -- 
        specialize (f_reasonable (fun _ => B_inhabited) nil).
        eassert _ as blah. 2: specialize (f_reasonable blah); clear blah.
        { eexists. simpl. eassumption. }
        specialize (f_reasonable o).
        
    
End ShortTheorems.
