# TD — Stockage de matrices en C

**Programmation modulaire et séparée, fichiers texte et allocation dynamique**

| Info | Détail |
|---|---|
| Public | Élèves de 3e année STI |
| Auteur | A. ADELL |
| Durée indicative | 2 séances de 1h30 (+ travail personnel) |
| Prérequis | pointeurs, malloc/free, structures, fopen/fprintf/fscanf |
| Produit final | une petite bibliothèque de 4 modules, un programme de démonstration et ses fichiers de test |
| Année universitaire | 2026–2027 |

---

## Sommaire

1. [Comprendre le problème](#1-comprendre-le-problème)
2. [Concevoir la bibliothèque](#2-concevoir-la-bibliothèque)
3. [Exercice 1 — Allocation et destruction](#3-exercice-1--allocation-et-destruction)
4. [Exercice 2 — Entrées-sorties](#4-exercice-2--entrées-sorties)
5. [Exercice 3 — Calcul matriciel](#5-exercice-3--calcul-matriciel)
6. [Exercice 4 — Démonstration complète](#6-exercice-4--démonstration-complète)

---

## Comment travailler avec ce sujet

- Les parties 1 et 2 posent le problème et fixent les interfaces : lisez-les entièrement avant d'écrire du code. Les prototypes de la partie 2 sont imposés.
- Les exercices 1 à 4 se font dans l'ordre : chaque module s'appuie sur les précédents.
- Chaque exercice se termine par des **questions de réflexion** (à préparer par écrit) et des **critères de validation** : un exercice n'est terminé que lorsque toutes les cases peuvent être cochées.

---

## 1. Comprendre le problème

### 1.1 Contexte

On souhaite écrire une petite bibliothèque C permettant de créer, sauvegarder, relire, afficher et calculer (somme et produit) des matrices d'entiers. Une bibliothèque est un ensemble de fonctions réutilisables qui ne contient pas de fonction `main` : elle est destinée à être utilisée par un ou plusieurs programmes.

Le code sera découpé en modules, chacun regroupant des fonctions d'un même thème : gestion de la mémoire, entrées-sorties, calcul. Un programme de démonstration, écrit dans un fichier séparé, utilisera ces modules.

### 1.2 Objectifs pédagogiques

À l'issue du TD, vous saurez :

1. Séparer l'interface d'un module (fichier `.h`) de son implémentation (fichier `.c`) ;
2. Compiler séparément plusieurs modules puis les assembler par édition de liens ;
3. Représenter une matrice de taille variable en mémoire et l'allouer dynamiquement, y compris en cas d'échec partiel ;
4. Établir et respecter des règles de propriété de la mémoire (qui alloue, qui utilise, qui libère) pour éviter toute fuite ;
5. Lire et écrire des données dans un fichier texte en vérifiant chaque opération ;
6. Programmer l'addition et la multiplication de matrices en contrôlant les dimensions ;
7. Concevoir une gestion d'erreurs uniforme et la vérifier par des tests.

### 1.3 Vocabulaire

| Terme | Définition |
|---|---|
| Module | Couple de fichiers `nom.h`/`nom.c` regroupant des fonctions d'un même thème. |
| Interface (fichier d'en-tête) | Fichier `.h` : ce que le module offre (types, constantes, prototypes). C'est le contrat avec les utilisateurs du module. |
| Implémentation | Fichier `.c` : comment le module réalise ce qu'il offre (définitions des fonctions). |
| Compilation séparée | Chaque `.c` est compilé indépendamment en un fichier objet `.o` (`gcc -c`). |
| Édition de liens | Assemblage des fichiers objets en un exécutable ; chaque appel de fonction est relié à sa définition. |
| Flux (`FILE *`) | Objet de la bibliothèque standard représentant un fichier ouvert (ou l'écran, le clavier). |
| Propriétaire d'une zone mémoire | Code chargé de libérer cette zone, exactement une fois. |
| Fuite mémoire | Zone allouée qui n'est jamais libérée. |

### 1.4 Les matrices

Une matrice de dimensions *n×p* est un tableau de nombres à *n* lignes et *p* colonnes (*n, p ≥ 1*). On note *a_ij* le coefficient situé ligne *i*, colonne *j*.

> **Indices mathématiques et indices C** : En mathématiques, les indices commencent à 1 ; en C, ils commencent à 0. Le coefficient *a₄₃* est donc `A.coef[3][2]` dans le programme. Toutes les boucles du TD vont de `0` à `nb_lignes - 1` (ou `nb_colonnes - 1`).

### 1.5 Le format du fichier texte

Une matrice est sauvegardée dans un fichier texte selon le format suivant :
- **Première ligne** : deux entiers, le nombre de lignes *n* puis le nombre de colonnes *p* ;
- **Lignes suivantes** : *n* lignes contenant chacune les *p* coefficients d'une ligne de la matrice, séparés par des espaces.

Exemple — Fichier `A.txt` :
```
4 3
25 48 84
15 33 11
45 88 10
0 12 -5
```

Deux règles précisent ce format :
1. **En écriture** (`mat_ecrire`) : format canonique — un seul espace entre deux coefficients, aucun espace en fin de ligne, un saut de ligne après chaque ligne.
2. **En lecture** (`mat_lire`) : on est tolérant sur les blancs — un nombre quelconque d'espaces, de tabulations ou de sauts de ligne peut séparer deux entiers. On est strict sur le contenu : dimensions entre 1 et `MAT_DIM_MAX`, exactement *n×p* coefficients.

---

## 2. Concevoir la bibliothèque

### 2.1 Organisation du projet

```
td_matrices/
├── matrice.h          ┐
├── matrice.c          ┘ module matrice (type Matrice, codes d'erreur, outils communs)
├── matrice_alloc.h    ┐
├── matrice_alloc.c    ┘ module matrice_alloc (créer et détruire une matrice)
├── matrice_io.h       ┐
├── matrice_io.c       ┘ module matrice_io (lire, écrire, afficher)
├── matrice_calcul.h   ┐
├── matrice_calcul.c   ┘ module matrice_calcul (additionner, multiplier)
├── main.c               programme de démonstration
├── test_ex1.c            tests exercice 1
├── test_ex2.c            tests exercice 2
├── test_ex3.c            tests exercice 3
└── donnees/
    ├── A.txt
    └── ...
```

### 2.2 Représentation d'une matrice en mémoire

```c
typedef struct matrice {
    int **coef;       /* coef[i][j] : ligne i, colonne j ; NULL si vide */
    int nb_lignes;    /* 0 si vide, sinon entre 1 et MAT_DIM_MAX */
    int nb_colonnes;  /* 0 si vide, sinon entre 1 et MAT_DIM_MAX */
} Matrice;

#define MAT_DIM_MAX   10000
#define MATRICE_VIDE   ((Matrice){ NULL, 0, 0 })
```

### 2.3 Gestion des erreurs

```c
typedef enum {
    MAT_OK = 0,            /* succès */
    MAT_ERR_ARGUMENT,      /* paramètre invalide (pointeur NULL, ...) */
    MAT_ERR_ALLOCATION,    /* échec de malloc/calloc */
    MAT_ERR_LECTURE,       /* erreur du flux pendant la lecture */
    MAT_ERR_FORMAT,        /* contenu du fichier mal formé ou tronqué */
    MAT_ERR_ECRITURE,      /* erreur du flux pendant l'écriture */
    MAT_ERR_DIMENSIONS,    /* dimensions incompatibles */
    MAT_ERR_DEPASSEMENT    /* résultat hors de l'intervalle des int */
} MatErreur;
```

### 2.4 Règles de propriété de la mémoire

| Règle | Description |
|---|---|
| **R1** | Toute variable `Matrice` est initialisée à `MATRICE_VIDE` dès sa déclaration. |
| **R2** | Une fonction qui réussit (`MAT_OK`) et remplit `*res` transfère la propriété du résultat à l'appelant, qui devra appeler `mat_detruire(&res)`. |
| **R3** | Une fonction qui échoue laisse `*res` égal à `MATRICE_VIDE` et a libéré tout ce qu'elle avait alloué : l'appelant n'a rien à libérer. |
| **R4** | Une fonction ne modifie et ne libère jamais une matrice reçue en entrée (`const Matrice *`). |
| **R5** | `*res` est un paramètre de sortie : son ancien contenu est écrasé. S'il possédait de la mémoire, l'appelant doit l'avoir détruite avant l'appel. |
| **R6** | `mat_detruire` remet la matrice à `MATRICE_VIDE` : un second appel est sans effet. |
| **R7** | Un fichier est fermé par le code qui l'a ouvert. Les fonctions de `matrice_io` reçoivent un flux déjà ouvert et ne le ferment jamais. |

### 2.5 Prototypes définitifs

```c
/* matrice.h -- outils communs */
const char *mat_message_erreur(MatErreur code);
int         mat_est_valide(const Matrice *m);

/* matrice_alloc.h */
MatErreur mat_allouer(Matrice *res, int nb_lignes, int nb_colonnes);
void      mat_detruire(Matrice *m);

/* matrice_io.h */
MatErreur mat_lire(FILE *f, Matrice *res);
MatErreur mat_ecrire(FILE *f, const Matrice *m);
void      mat_afficher(const char *nom, const Matrice *m);

/* matrice_calcul.h */
MatErreur mat_additionner(const Matrice *a, const Matrice *b, Matrice *res);
MatErreur mat_multiplier(const Matrice *a, const Matrice *b, Matrice *res);
```

### 2.6 Compilation séparée

```bash
# 1) Compilation séparée : un fichier objet par fichier source
gcc -std=c11 -Wall -Wextra -Wpedantic -g -c matrice.c
gcc -std=c11 -Wall -Wextra -Wpedantic -g -c matrice_alloc.c
gcc -std=c11 -Wall -Wextra -Wpedantic -g -c matrice_io.c
gcc -std=c11 -Wall -Wextra -Wpedantic -g -c matrice_calcul.c
gcc -std=c11 -Wall -Wextra -Wpedantic -g -c main.c

# 2) Édition de liens
gcc main.o matrice.o matrice_alloc.o matrice_io.o matrice_calcul.o -o demo_matrices
```

---

## 3. Exercice 1 — Allocation et destruction

**Fichiers à compléter** : `matrice.c` et `matrice_alloc.c`

**Objectif** : créer une matrice de dimensions quelconques sur le tas et la libérer sans fuite, y compris lorsqu'une allocation échoue en cours de route.

### Étapes

| Étape | Fichier | Description |
|---|---|---|
| **1.a** | `matrice.c` | Compléter les messages d'erreur (`MAT_ERR_DIMENSIONS`, `MAT_ERR_DEPASSEMENT`) |
| **1.b** | `matrice.c` | Écrire `mat_est_valide` (4 conditions avec `&&`) |
| **1.c** | `matrice_alloc.c` | Refuser les dimensions invalides |
| **1.d** | `matrice_alloc.c` | Réserver chaque ligne (boucle + gestion échec partiel) |
| **1.e** | `matrice_alloc.c` | Remplir le résultat (`res->coef`, `res->nb_lignes`, `res->nb_colonnes`) |
| **1.f** | `matrice_alloc.c` | Écrire `mat_detruire` (libérer lignes puis tableau) |

### Compiler et tester

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex1.c matrice.c matrice_alloc.c -o test_ex1
./test_ex1
valgrind --leak-check=full ./test_ex1
```

**Résultat attendu** : `Bilan : 16 / 16 vérifications réussies.`

### Questions de réflexion — Exercice 1

**Q3.1** Pourquoi `mat_detruire` prend-elle un `Matrice *` et non un `Matrice` ? Que se passerait-il, pour l'appelant, avec un passage par valeur ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q3.2** Combien d'appels à `calloc` et à `free` faut-il pour une matrice *n×p* ? Si la *k*-ième allocation échoue, combien de libérations `mat_allouer` doit-elle effectuer ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q3.3** Appeler deux fois `free` sur la même adresse est un comportement indéfini. Pourquoi appeler deux fois `mat_detruire` sur la même matrice est-il sans danger ? Est-ce encore vrai si l'on a fait une copie `Matrice b = a;` puis appelé `mat_detruire(&a)` et `mat_detruire(&b)` ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q3.4** Pourquoi `mat_allouer` commence-t-elle par l'affectation `*res = MATRICE_VIDE`, avant même de vérifier les dimensions ?

> *Réponse :* <!-- À COMPLÉTER -->

---

### Critères de validation — Exercice 1

- [ ] `test_ex1` compile sans aucun avertissement.
- [ ] `./test_ex1` affiche `Bilan : 16 / 16`.
- [ ] `valgrind --leak-check=full ./test_ex1` affiche `All heap blocks were freed`.
- [ ] Il ne reste aucune ligne provisoire dans `matrice.c` et `matrice_alloc.c`.

---

## 4. Exercice 2 — Entrées-sorties

**Fichier à compléter** : `matrice_io.c`

**Objectif** : afficher une matrice, l'enregistrer dans un fichier texte au format défini en partie 1, puis la relire en détectant toute donnée invalide. L'exercice 1 doit être terminé.

### Étapes

| Étape | Description |
|---|---|
| **2.a** | Afficher les coefficients (double boucle, `printf(" %8d", ...)`) |
| **2.b** | Écrire les coefficients dans le fichier (format canonique, vérifier chaque écriture) |
| **2.c** | Lire : vérifier les dimensions lues |
| **2.d** | Lire : réserver une matrice locale `tmp` |
| **2.e** | Lire : lire les coefficients avec `lire_entier` |
| **2.f** | Lire : transférer le résultat (`*res = tmp;`) |

### Compiler et tester

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex2.c matrice.c matrice_alloc.c matrice_io.c -o test_ex2
./test_ex2
valgrind --leak-check=full ./test_ex2
```

**Résultat attendu** : `Bilan : 14 / 14 vérifications réussies.`

### Questions de réflexion — Exercice 2

**Q4.1** Pourquoi `mat_lire` remplit-elle d'abord une matrice locale avant de l'affecter à `*res` ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q4.2** La lecture vérifie-t-elle que chaque ligne de la matrice est sur sa propre ligne de texte ? Est-ce gênant ? Justifiez le principe « tolérant en lecture, strict en écriture ».

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q4.3** Après l'appel `mat_lire(f, &m)`, le flux `f` est positionné après le dernier coefficient. Comment exploiter cette propriété pour stocker deux matrices dans un même fichier ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q4.4** Pourquoi `mat_ecrire` appelle-t-elle `fflush` avant de renvoyer `MAT_OK` ? Cela dispense-t-il l'appelant de tester `fclose` ?

> *Réponse :* <!-- À COMPLÉTER -->

---

### Critères de validation — Exercice 2

- [ ] `test_ex2` compile sans aucun avertissement.
- [ ] `./test_ex2` affiche `Bilan : 14 / 14`.
- [ ] `valgrind --leak-check=full ./test_ex2` affiche `All heap blocks were freed`.
- [ ] Aucune fonction de `matrice_io.c` n'appelle `fopen` ni `fclose`, et il ne reste aucune ligne provisoire.

---

## 5. Exercice 3 — Calcul matriciel

**Fichier à compléter** : `matrice_calcul.c`

**Objectif** : additionner et multiplier deux matrices en vérifiant leurs dimensions, sans jamais modifier les matrices d'entrée, et en produisant un résultat qui possède sa propre mémoire. L'exercice 1 doit être terminé.

### 5.1 L'addition

Deux matrices ne peuvent être additionnées que si elles ont exactement les mêmes dimensions *n×p*. Le résultat est de dimensions *n×p* :

*c_ij = a_ij + b_ij*

### 5.2 La multiplication

Le produit *C = A×B* n'est défini que si le nombre de colonnes de A est égal au nombre de lignes de B. Si A est *n×p* et B est *p×q*, alors C est *n×q* :

*c_ij = Σ(k=1..p) a_ik × b_kj*

### Étapes

| Étape | Description |
|---|---|
| **3.a** | Addition : contrôler les dimensions |
| **3.b** | Addition : réserver le résultat |
| **3.c** | Addition : calculer chaque coefficient (en `long long`) |
| **3.d** | Addition : transférer le résultat |
| **3.e** | Multiplication : contrôler les dimensions |
| **3.f** | Multiplication : réserver le résultat |
| **3.g** | Multiplication : la somme des produits (avec contrôle dépassement) |
| **3.h** | Multiplication : transférer le résultat |

### Compiler et tester

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex3.c matrice.c matrice_alloc.c matrice_calcul.c -o test_ex3
./test_ex3
valgrind --leak-check=full ./test_ex3
```

**Résultat attendu** : `Bilan : 14 / 14 vérifications réussies.`

### Questions de réflexion — Exercice 3

**Q5.1** Le paramètre `const Matrice *a` empêche-t-il d'écrire `a->coef[0][0] = 7;` ? Que protège exactement ce `const` ? Que faudrait-il changer pour que le compilateur refuse cette affectation ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q5.2** Pourquoi refuse-t-on l'appel `mat_additionner(&a, &b, &a)` alors que, mathématiquement, *a ← a+b* a un sens ? Que se passerait-il avec notre implémentation si on l'acceptait ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q5.3** Combien de multiplications d'entiers effectue `mat_multiplier` pour des matrices *n×p* et *p×q* ? Combien pour deux matrices *1000×1000* ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q5.4** Pourquoi ne suffit-il pas de calculer `int s = a + b;` puis de tester `s < a` pour détecter un dépassement ?

> *Réponse :* <!-- À COMPLÉTER -->

---

### Critères de validation — Exercice 3

- [ ] `test_ex3` compile sans aucun avertissement.
- [ ] `./test_ex3` affiche `Bilan : 14 / 14`.
- [ ] `valgrind --leak-check=full ./test_ex3` affiche `All heap blocks were freed`.
- [ ] Il ne reste aucune ligne provisoire dans `matrice_calcul.c`.

---

## 6. Exercice 4 — Démonstration complète

**Fichier à compléter** : `main.c`

**Objectif** : assembler les modules dans un programme qui lit deux matrices, calcule, affiche et enregistre le résultat, et qui traite proprement chaque erreur. Les exercices 1 à 3 doivent être terminés.

### Utilisation

```bash
./demo_matrices <add|mul> <fichier_A> <fichier_B> <fichier_R>
```

### Étapes

| Étape | Description |
|---|---|
| **4.a** | Afficher A et B avec `mat_afficher` |
| **4.b** | Calculer le résultat (ternaire `addition ? mat_additionner : mat_multiplier`) |
| **4.c** | Afficher R (`"R = A + B"` ou `"R = A x B"`) |
| **4.d** | Signaler le succès (afficher le nom du fichier, `statut = EXIT_SUCCESS`) |

### Compiler et tester

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -g \
    main.c matrice.c matrice_alloc.c matrice_io.c matrice_calcul.c \
    -o demo_matrices
```

### Scénarios de test

| # | Commande | Comportement attendu | Code sortie |
|---|---|---|---|
| 1 | `add A.txt B.txt R.txt` | Affiche A, B, R ; R.txt créé | 0 |
| 2 | `mul A.txt C.txt R.txt` | Idem, R de dimensions 4×2 | 0 |
| 3 | `add A.txt C.txt R.txt` | « dimensions incompatibles » | 1 |
| 4 | `mul A.txt B.txt R.txt` | Idem (4×3 par 4×3) | 1 |
| 5 | Fichier absent | « impossible d'ouvrir » + cause système | 1 |
| 6 | `invalide.txt` comme A | « fichier mal formé » | 1 |
| 7 | `tronque.txt` comme A | « fichier mal formé » | 1 |
| 8 | Résultat dans dossier inexistant | « impossible de créer » | 1 |
| 9 | Échec d'allocation (simulé) | Code `MAT_ERR_ALLOCATION`, aucune fuite | — |
| 10 | Arguments manquants ou opération inconnue | Message d'usage | 1 |

### Questions de réflexion — Exercice 4

**Q6.1** Pourquoi le message d'erreur est-il affiché par `main.c` (ou ses fonctions `static`) et non par `mat_lire` ? Pensez à un programme graphique qui réutiliserait la bibliothèque.

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q6.2** Pourquoi le résultat de `fclose` est-il testé dans `sauvegarder` mais pas dans `charger` ?

> *Réponse :* <!-- À COMPLÉTER -->

---

**Q6.3** Dans le scénario 8, le calcul a réussi mais l'enregistrement a échoué. Combien de matrices faut-il libérer ? Vérifiez que votre programme le fait.

> *Réponse :* <!-- À COMPLÉTER -->

---

### Critères de validation — Exercice 4

- [ ] Le programme compile sans aucun avertissement avec `-std=c11 -Wall -Wextra -Wpedantic`.
- [ ] `main.c` n'inclut que des en-têtes ; aucun module ne contient de fonction `main`.
- [ ] Les dix scénarios donnent le comportement attendu.
- [ ] Le fichier produit par le scénario 1 peut être relu : `./demo_matrices add R.txt R.txt R2.txt`.
- [ ] `valgrind` ne signale ni fuite ni accès invalide dans aucun scénario.
- [ ] Les trois programmes `test_ex1`, `test_ex2`, `test_ex3` affichent toujours un bilan complet.
