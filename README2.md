# Rapport TD — Stockage de matrices en C

**Élève :** <!-- À compléter -->
**Année :** 2026–2027

---

## Exercice 1 — Allocation et destruction

### Étapes réalisées

| Étape | Fichier | Description | Statut |
|---|---|---|---|
| 1.a | `matrice.c` | Messages d'erreur `MAT_ERR_DIMENSIONS` et `MAT_ERR_DEPASSEMENT` | ✅ |
| 1.b | `matrice.c` | `mat_est_valide` (4 conditions) | ✅ |
| 1.c | `matrice_alloc.c` | Refus des dimensions invalides | ✅ |
| 1.d | `matrice_alloc.c` | Allocation ligne par ligne + gestion échec partiel | ✅ |
| 1.e | `matrice_alloc.c` | Remplissage de `res->coef`, `res->nb_lignes`, `res->nb_colonnes` | ✅ |
| 1.f | `matrice_alloc.c` | `mat_detruire` | ✅ |

### Résultat des tests

```
Bilan : 16 / 16 vérifications réussies.
```

Compilation sans aucun avertissement avec :
```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex1.c matrice.c matrice_alloc.c -o test_ex1
```

---

### Questions de réflexion — Exercice 1

---

**Q3.1** Pourquoi `mat_detruire` prend-elle un `Matrice *` et non un `Matrice` ? Que se passerait-il, pour l'appelant, avec un passage par valeur ?

> `mat_detruire` reçoit un pointeur `Matrice *` car elle doit **modifier la variable de l'appelant** : après la destruction, elle remet `*m` à `MATRICE_VIDE` (champ `coef` remis à `NULL`, dimensions à 0). Avec un passage par valeur, la fonction travaillerait sur une **copie locale** de la structure : l'appelant ne verrait jamais la remise à `MATRICE_VIDE`, et `coef` resterait un pointeur pendouillant vers de la mémoire déjà libérée. Un deuxième appel involontaire à `free` provoquerait un comportement indéfini.

---

**Q3.2** Combien d'appels à `calloc` et à `free` faut-il pour une matrice *n×p* ? Si la *k*-ième allocation échoue, combien de libérations `mat_allouer` doit-elle effectuer ?

> Pour une matrice *n×p*, `mat_allouer` effectue **1 + n** appels à `calloc` :
> - 1 pour le tableau de `n` pointeurs de lignes (`int **coef`) ;
> - `n` pour les `n` tableaux de `p` entiers (une ligne chaque fois).
>
> En cas de succès, `mat_detruire` effectuera **n + 1** appels à `free` (les `n` lignes puis le tableau).
>
> Si la *k*-ième allocation échoue (en comptant à partir de 1) :
> - Si c'est le tableau de pointeurs (k = 1) : **0** libération de ligne, puis `free(coef)` → 1 `free` au total.
> - Si c'est la *k*-ième ligne (k ≥ 2, donc ligne numéro k-1) : on libère les **k-2** lignes déjà allouées, puis le tableau → **k-1** `free` au total.

---

**Q3.3** Appeler deux fois `free` sur la même adresse est un comportement indéfini. Pourquoi appeler deux fois `mat_detruire` sur la même matrice est-il sans danger ? Est-ce encore vrai si l'on a fait une copie `Matrice b = a;` puis appelé `mat_detruire(&a)` et `mat_detruire(&b)` ?

> `mat_detruire` est sans danger au deuxième appel car, à la fin du premier appel, elle remet `*m = MATRICE_VIDE` : `m->coef` vaut donc `NULL`. Au deuxième appel, la garde `if (m->coef != NULL)` est fausse, donc aucun `free` n't est exécuté.
>
> En revanche, si on fait `Matrice b = a;` puis `mat_detruire(&a)` et `mat_detruire(&b)`, c'est **dangereux** : `b.coef` est une copie de l'adresse `a.coef`. Après `mat_detruire(&a)`, `a.coef` est `NULL` mais `b.coef` pointe toujours vers la mémoire libérée. Le deuxième appel `mat_detruire(&b)` tentera de libérer deux fois la même mémoire → **comportement indéfini**. C'est pourquoi la règle R4 interdit de copier une `Matrice` par valeur lorsqu'on possède sa mémoire.

---

**Q3.4** Pourquoi `mat_allouer` commence-t-elle par l'affectation `*res = MATRICE_VIDE`, avant même de vérifier les dimensions ?

> Parce que `*res` est un **paramètre de sortie** dont le contenu initial est inconnu (règle R5) : l'appelant peut avoir passé une variable non initialisée. En mettant `*res` à `MATRICE_VIDE` dès le début, on garantit que, quel que soit le chemin d'erreur emprunté ensuite (dimensions invalides, allocation échouée…), `*res` est dans un état cohérent et sûr. Sans cette ligne, si la fonction renvoie une erreur avant d'avoir rien alloué, `*res` contiendrait des valeurs indéterminées et l'appelant ne pourrait pas appeler `mat_detruire` sans risque.

---

### Critères de validation — Exercice 1

- [x] `test_ex1` compile sans aucun avertissement.
- [x] `./test_ex1` affiche `Bilan : 16 / 16`.
- [x] `valgrind --leak-check=full ./test_ex1` affiche `All heap blocks were freed` — **11 allocs, 11 frees, 0 erreur**.

**Capture valgrind :**

![Résultat valgrind exercice 1](valgrind_ex1.jpg)
- [x] Il ne reste aucune ligne provisoire dans `matrice.c` et `matrice_alloc.c`.

---

## Exercice 2 — Entrées-sorties

> *À compléter.*

---

## Exercice 3 — Calcul matriciel

> *À compléter.*

---

## Exercice 4 — Démonstration complète

> *À compléter.*

