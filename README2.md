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

### Étapes réalisées

| Étape | Fichier | Description | Statut |
|---|---|---|---|
| 2.a | `matrice_io.c` | Afficher les coefficients avec `printf(" %8d", ...)` | ✅ |
| 2.b | `matrice_io.c` | Écriture au format canonique avec vérification des retours | ✅ |
| 2.c | `matrice_io.c` | Vérification des dimensions lues (`1` à `MAT_DIM_MAX`) | ✅ |
| 2.d | `matrice_io.c` | Réservation d'une matrice locale `tmp` | ✅ |
| 2.e | `matrice_io.c` | Lecture des coefficients via `lire_entier` et libération si échec | ✅ |
| 2.f | `matrice_io.c` | Transfert du résultat (`*res = tmp;`) et retour `MAT_OK` | ✅ |

### Résultat des tests

```
=== Exercice 2 : affichage (verification visuelle) ===
M (4 x 3) :
        1        2        3
        4        5        6
        7        8        9
       10       11       12
=== Exercice 2 : ecriture ===
[OK]    ouverture de test_ex2_sortie.txt en ecriture
[OK]    (2.b) mat_ecrire renvoie MAT_OK
[OK]    (2.b) le fichier contient exactement le format attendu
[OK]    (2.b) mat_ecrire refuse une matrice vide
=== Exercice 2 : relecture ===
[OK]    (2.f) mat_lire relit le fichier : MAT_OK
[OK]    (2.e) la matrice relue est identique
[OK]    (2.e) espaces et sauts de ligne en trop sont toleres
=== Exercice 2 : fichiers incorrects ===
[OK]    (2.c) fichier vide
[OK]    (2.c) dimension nulle
[OK]    (2.c) dimension negative
[OK]    (2.e) coefficient manquant
[OK]    (2.e) donnee non numerique
[OK]    (2.e) entier trop grand pour un int
=== Exercice 2 : echec d'allocation simule ===
[OK]    (2.d) mat_lire renvoie MAT_ERR_ALLOCATION proprement

Bilan : 14 / 14 vérifications réussies.
```

---

### Questions de réflexion — Exercice 2

**Q4.1** Pourquoi `mat_lire` remplit-elle d'abord une matrice locale avant de l'affecter à `*res` ?

> Pour respecter strictement la règle R3 de gestion de la mémoire : si la lecture échoue en cours de route (fichier mal formé, dimensions erronées, fichier tronqué, données non numériques), `mat_detruire(&tmp)` libère toute la mémoire déjà allouée et `*res` reste intact à l'état `MATRICE_VIDE`. L'affectation `*res = tmp;` n'a lieu que lorsque l'ensemble des coefficients a été lu avec succès.

---

**Q4.2** La lecture vérifie-t-elle que chaque ligne de la matrice est sur sa propre ligne de texte ? Est-ce gênant ? Justifiez le principe « tolérant en lecture, strict en écriture ».

> Non, la lecture ne le vérifie pas car `lire_entier` utilise `fscanf` avec `%s` puis `strtol`, ce qui traite de manière équivalente tous les caractères d'espacement (espaces, tabulations, retours à la ligne `\n`). 
> Ce n'est pas gênant car le nombre exact de coefficients attendus est strictement contrôlé ($n \times p$).
> Le principe « tolérant en lecture, strict en écriture » (loi de Postel / Robustness Principle) permet d'accepter des fichiers générés par d'autres logiciels, éditeurs ou systèmes d'exploitation (variations de retours chariot, espaces superflus), tout en garantissant que nos propres sorties sont rigoureusement canoniques, propres et universellement lisibles.

---

**Q4.3** Après l'appel `mat_lire(f, &m)`, le flux `f` est positionné après le dernier coefficient. Comment exploiter cette propriété pour stocker deux matrices dans un même fichier ?

> Comme `mat_lire` ne ferme pas le flux (règle R7) et s'arrête exactement après avoir lu les $n \times p$ coefficients, le curseur du fichier reste positionné juste au début des données suivantes. On peut donc enchaîner directement `mat_lire(f, &m1)` puis `mat_lire(f, &m2)` sur le même flux sans devoir calculer d'offset ni appeler `fseek`. De même en écriture, on appelle successivement `mat_ecrire(f, &m1)` puis `mat_ecrire(f, &m2)`.

---

**Q4.4** Pourquoi `mat_ecrire` appelle-t-elle `fflush` avant de renvoyer `MAT_OK` ? Cela dispense-t-il l'appelant de tester `fclose` ?

> `fflush(f)` force l'écriture immédiate des données présentes dans le tampon de la bibliothèque standard vers le système d'exploitation. Cela permet à `mat_ecrire` d'intercepter une erreur d'écriture (par exemple disque saturé ou canal interrompu) et de renvoyer `MAT_ERR_ECRITURE`.
> Cependant, cela ne dispense pas l'appelant de tester la valeur de retour de `fclose(f)`, car `fclose` finalise la clôture du fichier au niveau du système d'exploitation (libération du descripteur de fichier) et peut lui-même échouer.

---

### Critères de validation — Exercice 2

- [x] `test_ex2` compile sans aucun avertissement.
- [x] `./test_ex2` affiche `Bilan : 14 / 14`.
- [x] `valgrind --leak-check=full ./test_ex2` affiche `All heap blocks were freed` — **51 allocs, 51 frees, 0 erreur**.

**Capture valgrind :**

![Résultat valgrind exercice 2](valgrind_ex2.png)
- [x] Aucune fonction de `matrice_io.c` n'appelle `fopen` ni `fclose`, et il ne reste aucune ligne provisoire.

---

## Exercice 3 — Calcul matriciel

> *À compléter.*

---

## Exercice 4 — Démonstration complète

> *À compléter.*

