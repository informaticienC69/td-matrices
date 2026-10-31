# Rapport de Projet — Bibliothèque C de Manipulation de Matrices (TD Matrices)

## 1. En-tête

* **Titre du TD :** Manipulation et Calcul Matriciel en C — Allocation dynamique, Persistance et Robustesse Mémoire
* **Membres du trinôme :**
  * **Hady KALOGA** (Chef de groupe, GitHub : `informaticienC69`) — Responsable Exercice 1 et Exercice 3
  * **Simone Lassanadio FALL** (GitHub : `SIMONEFALL`) — Responsable Exercice 2
  * **Adji Deguène BEISSE** (GitHub : `beisse25`) — Responsable Exercice 4
* **Formation & Groupe :** Élèves-Ingénieurs 3e année STI — Groupe de TD 1
* **Date de remise :** 31 Octobre 2026
* **Dépôt GitHub :** [https://github.com/informaticienC69/td_matrices.git](https://github.com/informaticienC69/td_matrices.git) (Tag : `rendu`)

---

## Sommaire

1. [En-tête](#1-en-tête)
2. [Introduction](#2-introduction)
3. [Conception](#3-conception)
   - [3.1 Schéma architectural des modules](#31-schéma-architectural-des-modules)
   - [3.2 Graphe des inclusions et rôle des gardes](#32-graphe-des-inclusions-et-rôle-des-gardes)
   - [3.3 Règles de propriété de la mémoire (R1 à R7)](#33-règles-de-propriété-de-la-mémoire-r1-à-r7)
   - [3.4 Choix techniques de conception](#34-choix-techniques-de-conception)
   - [3.5 Système de construction (Makefile)](#35-système-de-construction-makefile)
4. [Réalisation, exercice par exercice](#4-réalisation-exercice-par-exercice)
   - [4.1 Exercice 1 — Utilitaires fondamentaux et Allocation dynamique](#41-exercice-1--utilitaires-fondamentaux-et-allocation-dynamique)
   - [4.2 Exercice 2 — Entrées-sorties, Affichage et Persistance](#42-exercice-2--entrées-sorties-affichage-et-persistance)
   - [4.3 Exercice 3 — Calcul arithmétique et Détection des dépassements](#43-exercice-3--calcul-arithmétique-et-détection-des-dépassements)
   - [4.4 Exercice 4 — Intégration dans le programme principal](#44-exercice-4--intégration-dans-le-programme-principal)
5. [Vérifications mémoire (Valgrind)](#5-vérifications-mémoire-valgrind)
   - [5.1 Synthèse des tests unitaires](#51-synthèse-des-tests-unitaires)
   - [5.2 Validation sur le programme de démonstration](#52-validation-sur-le-programme-de-démonstration)
6. [Démonstration finale](#6-démonstration-finale)
7. [Bilan, difficultés et aides extérieures](#7-bilan-difficultés-et-aides-extérieures)

---

## 2. Introduction

### Contexte et Objectifs
Ce travail pratique est consacré à la réalisation complète d'une bibliothèque modulaire de calcul matriciel en langage C (norme ISO C11). Manipuler des matrices en C pose un défi fondamental : la mémoire vive sur le tas (*heap*) doit être allouée dynamiquement et libérée manuellement sans bénéficier d'un ramasse-miettes (*garbage collector*). Le moindre oubli conduit à des fuites de mémoire (*memory leaks*), tandis qu'une désallocation prématurée ou multiple mène à des accès hors bornes, des corruptions de mémoire ou des arrêts anormaux par *Segmentation Fault*.

L'objectif de ce TD est quadruple :
1. Concevoir une architecture logicielle modulaire garantissant l'étanchéité absolue entre les contrats d'interfaces publics (fichiers `.h` immuables) et les détails d'implémentation (fichiers `.c`).
2. Implémenter un système d'allocation dynamique résistant aux pannes, capable d'annuler proprement ses opérations intermédiaires en cas de manque de mémoire (*rollback*).
3. Assurer la persistance robuste de matrices sur disque selon la loi de Postel (*« Soyez libéral dans ce que vous acceptez, et strict dans ce que vous émettez »*).
4. Implémenter l'addition et la multiplication matricielle avec contrôle rigoureux des dépassements de capacité sur les entiers signés (*integer overflow*), comportement indéfini en standard C.

### État de fonctionnement à la remise
À la remise de ce projet, **100 % des fonctionnalités attendues sont pleinement opérationnelles** :
- **Exercice 1 (`matrice.c`, `matrice_alloc.c`) :** 16 / 16 vérifications réussies au banc `test_ex1`.
- **Exercice 2 (`matrice_io.c`) :** 14 / 14 vérifications réussies au banc `test_ex2`.
- **Exercice 3 (`matrice_calcul.c`) :** 14 / 14 vérifications réussies au banc `test_ex3`.
- **Exercice 4 (`main.c`) :** Les 10 scénarios d'exécution du cahier des charges s'exécutent avec succès.
- **Bilan Valgrind :** Zéro fuite mémoire (`0 bytes in 0 blocks`) et zéro erreur contextuelle constatée sur tous les binaires et dans tous les scénarios (nominaux comme erronés).

---

## 3. Conception

### 3.1 Schéma architectural des modules

Le système est décomposé en 4 modules spécialisés et un point d'entrée exécutable :

```
                        +----------------------+
                        |  main (main.c)       |
                        +----------+-----------+
                                   |
         +-------------------------+-------------------------+
         |                         |                         |
         v                         v                         v
+-----------------+       +-----------------+       +-----------------+
|  matrice_io     |       |  matrice_calcul |       |  matrice_alloc  |
+--------+--------+       +--------+--------+       +--------+--------+
         |                         |                         |
         +-------------------------+-------------------------+
                                   |
                                   v
                        +---------------------+
                        |  matrice (base)     |
                        +---------------------+
```

- **Module `matrice` (`matrice.h`, `matrice.c`) :** Cœur du système. Définit le type `Matrice`, l'état neutre `MATRICE_VIDE`, l'énumération des codes d'erreur `MatErreur` et les utilitaires généraux (`mat_est_valide`, `mat_message_erreur`).
- **Module `matrice_alloc` (`matrice_alloc.h`, `matrice_alloc.c`) :** Responsable du cycle de vie mémoire. Fournit `mat_allouer` (avec détection de pannes) et `mat_detruire`.
- **Module `matrice_io` (`matrice_io.h`, `matrice_io.c`) :** Responsable de l'affichage console (`mat_afficher`), de l'écriture formatée (`mat_ecrire`) et de l'analyse lexicale robuste en lecture (`mat_lire`).
- **Module `matrice_calcul` (`matrice_calcul.h`, `matrice_calcul.c`) :** Moteur arithmétique. Fournit `mat_additionner` et `mat_multiplier` protégés contre le dépassement arithmétique.
- **Client de démonstration (`main.c`) :** Analyse les arguments CLI, charge les matrices, déclenche le calcul, affiche les résultats, sauvegarde sur fichier et centralise le nettoyage final.

### 3.2 Graphe des inclusions et rôle des gardes

Les dépendances d'inclusion entre en-têtes sont structurées de façon strictement hiérarchique :

```
    matrice.h  <------- matrice_alloc.h
        ^                       ^
        |                       |
    matrice_io.h         matrice_calcul.h
```

- `matrice.h` : Ne dépend d'aucun autre en-tête du projet.
- `matrice_alloc.h` : Inclut `matrice.h`.
- `matrice_io.h` : Inclut `matrice.h` et `<stdio.h>`.
- `matrice_calcul.h` : Inclut `matrice.h`.
- `main.c` : Inclut directement les 4 en-têtes (`matrice.h`, `matrice_alloc.h`, `matrice_io.h`, `matrice_calcul.h`).

#### Rôle indispensable des gardes `#ifndef`
Chaque fichier d'en-tête est encadré par des gardes de préprocesseur (par exemple `#ifndef MATRICE_H` / `#define MATRICE_H` ... `#endif`). En C, redéfinir un type (`typedef struct matrice Matrice;`) ou une énumération au sein de la même unité de compilation provoque une erreur de compilation (*redefinition of typedef*). Dans notre cas, `main.c` inclut `matrice_alloc.h` et `matrice_io.h`, qui incluent tous deux `matrice.h`. Sans les gardes d'inclusion, `matrice.h` serait traité plusieurs fois dans `main.c`, bloquant immédiatement la compilation. Les gardes assurent une inclusion idempotente.

### 3.3 Règles de propriété de la mémoire (R1 à R7)

Pour rendre les fuites impossibles par conception, 7 règles strictes ont guidé chaque ligne de code :

- **R1 (Initialisation immédiate) :** Toute variable locale de type `Matrice` est obligatoirement initialisée à `MATRICE_VIDE` dès sa déclaration (`Matrice m = MATRICE_VIDE;`). Cela garantit qu'aucun pointeur non initialisé ne pointe vers une zone aléatoire de la pile.
- **R2 (Transfert de propriété) :** Une fonction qui alloue une matrice pour la renvoyer dans `*res` en transfère l'entière propriété à l'appelant. L'appelant assume la charge d'appeler `mat_detruire(&m)`.
- **R3 (Nettoyage systématique sur échec) :** En cas d'erreur survenant au milieu d'un traitement, la fonction libère l'intégralité des allocations intermédiaires déjà réservées et laisse `*res` dans l'état `MATRICE_VIDE`.
- **R4 (Immutabilité des entrées) :** Les matrices passées en entrée (`const Matrice *a`) ne sont jamais modifiées ni libérées. L'appelant conserve leur propriété intacte. La copie superficielle (`b = a`) est formellement bannie pour éviter les alias de pointeurs.
- **R5 (Écrasement sécurisé du résultat) :** Le pointeur `*res` est considéré comme une sortie pure. La fonction commence par affecter `*res = MATRICE_VIDE;`. Si `res == a` ou `res == b`, l'appel est rejeté d'emblée (`MAT_ERR_ARGUMENT`) pour éviter l'écrasement destructif des opérandes.
- **R6 (Idempotence de destruction) :** `mat_detruire(m)` remet `*m` à `MATRICE_VIDE` dès la libération achevée. Si `mat_detruire` est rappelée sur la même variable, elle constate que `m->coef == NULL` et n'effectue rien (*no-op*), prévenant tout *double free*.
- **R7 (Propriété des flux) :** Tout flux `FILE *` ouvert par une fonction appelante doit être fermé par cette même fonction. Les fonctions de bibliothèque (`mat_lire`, `mat_ecrire`) exploitent le flux sans jamais appeler `fclose`.

### 3.4 Choix techniques de conception

- **Utilisation du mot-clé `static` :** Toutes les fonctions utilitaires internes à un fichier source (comme `lire_entier` dans `matrice_io.c`, `verifier_parametres` et `tient_dans_int` dans `matrice_calcul.c`, ou `charger` et `sauvegarder` dans `main.c`) sont déclarées `static`. Ce choix restreint leur portée à l'unité de compilation courante, évitant la pollution de la table des symboles globale et prévenant les collisions de noms lors de l'édition des liens.
- **Gestion de l'échec partiel d'allocation (Rollback) :** L'allocation matricielle $n \times p$ nécessite $1 + n$ requêtes distinctes à `calloc`. Si la $i$-ième ligne échoue, le programme rembobine de $i-1$ jusqu'à $0$ pour libérer les lignes déjà allouées, puis détruit le tableau maître de pointeurs avant de propager l'erreur `MAT_ERR_ALLOCATION`.
- **Détection des débordements d'entiers :** L'addition de deux `int` peut déborder les bornes $[ \text{INT\_MIN}, \text{INT\_MAX} ]$. Comme le dépassement signé est un comportement indéfini en C, nous effectuons l'addition dans le type 64 bits `long long`. Pour le produit matriciel, nous vérifions à chaque terme du produit scalaire si l'addition du produit $p$ violerait `LLONG_MAX` ou `LLONG_MIN`, avant d'agréger dans l'accumulateur.

### 3.5 Système de construction (Makefile)

Un `Makefile` complet a été conçu à la racine du projet afin de permettre une compilation automatisée, propre et conforme aux standards rigoureux exigés :

```makefile
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -g
TEST_CFLAGS = $(CFLAGS) -DMAT_TEST_ALLOC

all: test_ex1 test_ex2 test_ex3 demo_matrices

test_ex1: test_ex1.c matrice.c matrice_alloc.c
	$(CC) $(TEST_CFLAGS) $^ -o $@

test_ex2: test_ex2.c matrice.c matrice_alloc.c matrice_io.c
	$(CC) $(TEST_CFLAGS) $^ -o $@

test_ex3: test_ex3.c matrice.c matrice_alloc.c matrice_calcul.c
	$(CC) $(TEST_CFLAGS) $^ -o $@

demo_matrices: main.c matrice.c matrice_alloc.c matrice_io.c matrice_calcul.c
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f *.o test_ex1 test_ex2 test_ex3 demo_matrices *.exe test_ex2_sortie.txt donnees/R.txt donnees/R2.txt

.PHONY: all clean
```

---

## 4. Réalisation, exercice par exercice

### 4.1 Exercice 1 — Utilitaires fondamentaux et Allocation dynamique
*Responsable : Hady KALOGA*

#### Code implémenté

Dans `matrice.c` :
```c
/* Étape (1.a) : Ajout des libellés d'erreur */
const char *mat_message_erreur(MatErreur code)
{
    switch (code) {
    /* ... cas existants ... */
    case MAT_ERR_DIMENSIONS:  return "dimensions incompatibles";
    case MAT_ERR_DEPASSEMENT: return "dépassement de capacité";
    default:                  break;
    }
    return "erreur inconnue";
}

/* Étape (1.b) : Validation complète d'une matrice */
int mat_est_valide(const Matrice *m)
{
    return m != NULL 
        && m->coef != NULL 
        && m->nb_lignes >= 1 && m->nb_lignes <= MAT_DIM_MAX 
        && m->nb_colonnes >= 1 && m->nb_colonnes <= MAT_DIM_MAX;
}
```

Dans `matrice_alloc.c` :
```c
/* Étape (1.c) : Contrôle des bornes */
if (nb_lignes < 1 || nb_lignes > MAT_DIM_MAX)
    return MAT_ERR_ARGUMENT;
if (nb_colonnes < 1 || nb_colonnes > MAT_DIM_MAX)
    return MAT_ERR_ARGUMENT;

/* Étape (1.d) : Allocation ligne par ligne avec désallocation inverse */
int **coef = mat_calloc((size_t)nb_lignes, sizeof *coef);
if (coef == NULL)
    return MAT_ERR_ALLOCATION;

for (int i = 0; i < nb_lignes; i++) {
    coef[i] = mat_calloc((size_t)nb_colonnes, sizeof(*coef[i]));
    if (coef[i] == NULL) {
        for (int k = i - 1; k >= 0; k--)
            free(coef[k]);
        free(coef);
        return MAT_ERR_ALLOCATION;
    }
}

/* Étape (1.e) : Renseignement des champs de la structure */
res->coef        = coef;
res->nb_lignes   = nb_lignes;
res->nb_colonnes = nb_colonnes;
return MAT_OK;

/* Étape (1.f) : Destruction hiérarchique et remise à l'état neutre */
void mat_detruire(Matrice *m)
{
    if (m == NULL)
        return;

    if (m->coef != NULL) {
        for (int i = 0; i < m->nb_lignes; i++)
            free(m->coef[i]);
        free(m->coef);
    }
    *m = MATRICE_VIDE;
}
```

#### Réponses aux questions de réflexion (Exercice 1)

**Q3.1 : Pourquoi `mat_detruire` prend-elle un `Matrice *` et non un `Matrice` ? Que se passerait-il avec un passage par valeur ?**  
> En C, tout passage de paramètre s'opère par valeur (copie). Si `mat_detruire` prenait une `Matrice` par valeur, la fonction pourrait certes libérer les blocs sur le tas via `m.coef[i]`, mais l'instruction `m = MATRICE_VIDE;` ne modifierait que sa copie locale sur la pile. Pour la fonction appelante, le champ `m.coef` conserverait son adresse initiale pointant vers une zone désormais désallouée (*dangling pointer*). Tout appel ultérieur tenterait une seconde libération (*double free*), causant un plantage. L'utilisation d'un pointeur `Matrice *` est indispensable pour modifier directement la variable de l'appelant et positionner `coef` à `NULL`.

**Q3.2 : Combien d'appels à `calloc` et à `free` faut-il pour une matrice $n \times p$ ? Si la $k$-ième allocation échoue, combien de libérations `mat_allouer` doit-elle effectuer ?**  
> L'allocation d'une matrice $n \times p$ requiert $1 + n$ allocations (1 pour le tableau maître de $n$ pointeurs, puis $n$ pour chacune des lignes). Symétriquement, `mat_detruire` effectue $n + 1$ libérations `free`.  
> Si la $k$-ième allocation globale échoue :
> - Si $k=1$ (échec du tableau maître), **0 libération** n'est nécessaire.
> - Si $k \ge 2$ (échec lors de l'allocation de la ligne d'indice $i = k - 2$), le tableau maître et $k-2$ lignes ont déjà été réservés. La fonction doit donc effectuer $(k - 2) + 1 = \mathbf{k - 1}$ **libérations** avant de renvoyer l'erreur.

**Q3.3 : Pourquoi appeler deux fois `mat_detruire` sur la même matrice est-il sans danger ? Est-ce encore vrai si l'on a fait une copie `Matrice b = a;` ?**  
> Le double appel est anodin grâce à l'étape (1.f) qui applique `*m = MATRICE_VIDE`. Le premier appel libère le tas et assigne `m->coef = NULL`. Le second appel constate que `m->coef == NULL` et saute la boucle de libération sans exécuter aucun `free`.  
> En revanche, après une copie superficielle `Matrice b = a;`, les pointeurs `a.coef` et `b.coef` pointent vers les mêmes adresses du tas. Appeler `mat_detruire(&a)` libère la mémoire et met `a.coef = NULL`, mais laisse `b.coef` intact. L'appel consécutif `mat_detruire(&b)` provoque alors un *double free* fatal.

**Q3.4 : Pourquoi `mat_allouer` commence-t-elle par l'affectation `*res = MATRICE_VIDE`, avant même de vérifier les dimensions ?**  
> Selon la règle de robustesse R3, si une fonction échoue, la variable résultat doit être laissée dans un état neutre et prévisible. En plaçant `*res = MATRICE_VIDE` dès la première ligne, on garantit que même si l'appelant fournit des dimensions illégales (ex: $0 \times 4$), la variable de l'appelant est nettoyée. S'il invoque par la suite un bloc de nettoyage appelant `mat_detruire(res)`, aucun comportement indéfini ne surviendra.

#### Sortie du test unitaire (`./test_ex1`)
```
=== Exercice 1 : matrice.c ===
[OK]    (1.a) message pour MAT_ERR_DIMENSIONS
[OK]    (1.a) message pour MAT_ERR_DEPASSEMENT
[OK]    (1.b) une matrice 1 x 2 est valide
[OK]    (1.b) NULL n'est pas valide
[OK]    (1.b) MATRICE_VIDE n'est pas valide
[OK]    (1.b) une matrice de 0 ligne n'est pas valide
=== Exercice 1 : matrice_alloc.c ===
[OK]    (1.c) mat_allouer refuse 0 ligne
[OK]    (1.c) mat_allouer refuse -2 colonnes
[OK]    (1.c) mat_allouer refuse une dimension > MAT_DIM_MAX
[OK]    (1.e) mat_allouer(&m, 3, 4) renvoie MAT_OK
[OK]    (1.e) m a 3 lignes et 4 colonnes
[OK]    (1.d) tous les coefficients valent 0
[OK]    (1.f) apres mat_detruire, m est vide
[OK]    (1.f) un second mat_detruire est sans danger
[OK]    (1.f) mat_detruire(NULL) ne plante pas
=== Exercice 1 : echecs d'allocation simules ===
[OK]    (1.d) chaque echec renvoie MAT_ERR_ALLOCATION et laisse *res vide

Bilan : 16 / 16 verifications reussies.
Pensez a verifier l'absence de fuite : valgrind --leak-check=full ./test_ex1
```

---

### 4.2 Exercice 2 — Entrées-sorties, Affichage et Persistance
*Responsable : Simone Lassanadio FALL*

#### Code implémenté dans `matrice_io.c`

```c
/* Étape (2.a) : Affichage formaté */
void mat_afficher(const char *nom, const Matrice *m)
{
    if (nom == NULL) nom = "matrice";
    if (!mat_est_valide(m)) {
        printf("%s : matrice vide ou invalide\n", nom);
        return;
    }
    printf("%s (%d x %d) :\n", nom, m->nb_lignes, m->nb_colonnes);

    for (int i = 0; i < m->nb_lignes; i++) {
        for (int j = 0; j < m->nb_colonnes; j++)
            printf(" %8d", m->coef[i][j]);
        putchar('\n');
    }
}

/* Étape (2.b) : Écriture sur flux avec détection d'erreurs d'E/S */
MatErreur mat_ecrire(FILE *f, const Matrice *m)
{
    if (f == NULL || !mat_est_valide(m))
        return MAT_ERR_ARGUMENT;

    if (fprintf(f, "%d %d\n", m->nb_lignes, m->nb_colonnes) < 0)
        return MAT_ERR_ECRITURE;

    for (int i = 0; i < m->nb_lignes; i++) {
        for (int j = 0; j < m->nb_colonnes; j++) {
            if (fprintf(f, j == 0 ? "%d" : " %d", m->coef[i][j]) < 0)
                return MAT_ERR_ECRITURE;
        }
        if (fputc('\n', f) == EOF)
            return MAT_ERR_ECRITURE;
    }

    if (fflush(f) == EOF)
        return MAT_ERR_ECRITURE;
    return MAT_OK;
}

/* Étapes (2.c à 2.f) : Lecture sécurisée sur variable locale */
MatErreur mat_lire(FILE *f, Matrice *res)
{
    if (res == NULL) return MAT_ERR_ARGUMENT;
    *res = MATRICE_VIDE;
    if (f == NULL) return MAT_ERR_ARGUMENT;

    int nb_lignes = 0, nb_colonnes = 0;
    MatErreur err = lire_entier(f, &nb_lignes);
    if (err == MAT_OK)
        err = lire_entier(f, &nb_colonnes);
    if (err != MAT_OK)
        return err;

    /* (2.c) Validation des dimensions lues */
    if (nb_lignes < 1 || nb_lignes > MAT_DIM_MAX
        || nb_colonnes < 1 || nb_colonnes > MAT_DIM_MAX)
        return MAT_ERR_FORMAT;

    /* (2.d) Matrice temporaire locale */
    Matrice tmp;
    err = mat_allouer(&tmp, nb_lignes, nb_colonnes);
    if (err != MAT_OK)
        return err;

    /* (2.e) Lecture coefficient par coefficient */
    for (int i = 0; i < nb_lignes; i++) {
        for (int j = 0; j < nb_colonnes; j++) {
            err = lire_entier(f, &tmp.coef[i][j]);
            if (err != MAT_OK) {
                mat_detruire(&tmp);
                return err;
            }
        }
    }

    /* (2.f) Transfert atomique du résultat */
    *res = tmp;
    return MAT_OK;
}
```

#### Réponses aux questions de réflexion (Exercice 2)

**Q4.1 : Pourquoi `mat_lire` remplit-elle d'abord une matrice locale avant de l'affecter à `*res` ?**  
> C'est l'application du principe de transaction atomique (« tout ou rien »). Si `mat_lire` réservait la mémoire directement dans `*res`, une erreur rencontrée au cours de la lecture du fichier (fichier tronqué, valeur non numérique) laisserait la matrice de l'appelant partiellement construite, corrompant son état. En utilisant une matrice locale `tmp`, si une anomalie se produit, `tmp` est immédiatement détruite et `*res` demeure inviolé à `MATRICE_VIDE` (règle R3).

**Q4.2 : La lecture vérifie-t-elle que chaque ligne de la matrice est sur sa propre ligne de texte ? Est-ce gênant ? Justifiez le principe « tolérant en lecture, strict en écriture ».**  
> Non, la fonction ne vérifie pas la disposition physique des lignes car `fscanf("%31s")` consomme indifféremment espaces, tabulations et sauts de ligne (`\n` ou `\r\n`). Ce n'est absolument pas gênant puisque le nombre total d'entiers lus ($n \times p$) est rigoureusement validé. Ce comportement applique fidèlement la loi de Postel : nous tolérons en entrée des fichiers aux séparateurs variés générés par divers systèmes d'exploitation, tout en produisant en écriture (`mat_ecrire`) un format strictement canonique et parfaitement indenté.

**Q4.3 : Après l'appel `mat_lire(f, &m)`, le flux `f` est positionné après le dernier coefficient. Comment exploiter cette propriété pour stocker deux matrices dans un même fichier ?**  
> Comme `mat_lire` s'arrête exactement à la fin du $n \times p$-ième entier et ne ferme jamais le descripteur `FILE *` (règle R7), la tête de lecture reste positionnée au début de la matrice suivante. Pour lire deux matrices consécutives, il suffit d'enchaîner deux appels : `mat_lire(f, &m1); mat_lire(f, &m2);`. De la même manière, on peut écrire deux matrices consécutives dans un même flux via `mat_ecrire(f, &m1); mat_ecrire(f, &m2);`.

**Q4.4 : Pourquoi `mat_ecrire` appelle-t-elle `fflush` avant de renvoyer `MAT_OK` ? Cela dispense-t-il l'appelant de tester `fclose` ?**  
> Les entrées-sorties C utilisent des mémoires tampons (*buffers*). L'appel `fflush(f)` force le déversement immédiat de ces données en attente vers le système de fichiers, permettant d'intercepter une erreur matérielle d'E/S (disque plein, quota dépassé) avant d'émettre `MAT_OK`. Cela ne dispense cependant pas de tester le retour de `fclose(f)` dans l'appelant : `fclose` libère les structures associées du noyau et inscrit les métadonnées de fermeture, opérations qui peuvent également échouer de façon indépendante.

#### Sortie du test unitaire (`./test_ex2`)
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

Bilan : 14 / 14 verifications reussies.
Pensez a verifier l'absence de fuite : valgrind --leak-check=full ./test_ex2
```

---

### 4.3 Exercice 3 — Calcul arithmétique et Détection des dépassements
*Responsable : Hady KALOGA*

#### Code implémenté dans `matrice_calcul.c`

```c
/* Addition matricielle (étapes 3.a à 3.d) */
MatErreur mat_additionner(const Matrice *a, const Matrice *b, Matrice *res)
{
    MatErreur err = verifier_parametres(a, b, res);
    if (err != MAT_OK)
        return err;

    /* (3.a) Contrôle dimensionnel */
    if (a->nb_lignes != b->nb_lignes || a->nb_colonnes != b->nb_colonnes)
        return MAT_ERR_DIMENSIONS;

    /* (3.b) Allocation du réceptacle */
    Matrice r = MATRICE_VIDE;
    err = mat_allouer(&r, a->nb_lignes, a->nb_colonnes);
    if (err != MAT_OK)
        return err;

    for (int i = 0; i < r.nb_lignes; i++) {
        for (int j = 0; j < r.nb_colonnes; j++) {
            /* (3.c) Somme en arithmétique 64 bits */
            long long s = (long long)a->coef[i][j] + (long long)b->coef[i][j];
            if (!tient_dans_int(s)) {
                mat_detruire(&r);
                return MAT_ERR_DEPASSEMENT;
            }
            r.coef[i][j] = (int)s;
        }
    }

    /* (3.d) Transfert de propriété */
    *res = r;
    return MAT_OK;
}

/* Multiplication matricielle (étapes 3.e à 3.h) */
MatErreur mat_multiplier(const Matrice *a, const Matrice *b, Matrice *res)
{
    MatErreur err = verifier_parametres(a, b, res);
    if (err != MAT_OK)
        return err;

    /* (3.e) Dimensions compatibles : colonnes de a == lignes de b */
    if (a->nb_colonnes != b->nb_lignes)
        return MAT_ERR_DIMENSIONS;

    /* (3.f) Dimensions produit : lignes de a x colonnes de b */
    Matrice r = MATRICE_VIDE;
    err = mat_allouer(&r, a->nb_lignes, b->nb_colonnes);
    if (err != MAT_OK)
        return err;

    for (int i = 0; i < r.nb_lignes; i++) {
        for (int j = 0; j < r.nb_colonnes; j++) {
            long long s = 0;

            /* (3.g) Somme des produits avec garde de débordement 64 bits */
            for (int k = 0; k < a->nb_colonnes; k++) {
                long long p = (long long)a->coef[i][k] * b->coef[k][j];
                if ((p > 0 && s > LLONG_MAX - p) || (p < 0 && s < LLONG_MIN - p)) {
                    mat_detruire(&r);
                    return MAT_ERR_DEPASSEMENT;
                }
                s += p;
            }

            if (!tient_dans_int(s)) {
                mat_detruire(&r);
                return MAT_ERR_DEPASSEMENT;
            }
            r.coef[i][j] = (int)s;
        }
    }

    /* (3.h) Transfert du résultat */
    *res = r;
    return MAT_OK;
}
```

#### Réponses aux questions de réflexion (Exercice 3)

**Q5.1 : Le paramètre `const Matrice *a` empêche-t-il d'écrire `a->coef[0][0] = 7;` ? Que protège exactement ce `const` ? Que faudrait-il changer pour interdire cette affectation ?**  
> Non, le compilateur autorise parfaitement l'affectation `a->coef[0][0] = 7;`. Le qualificateur `const Matrice *a` assure uniquement la constance superficielle des champs de la structure `Matrice` (il interdit par exemple d'écrire `a->nb_lignes = 3;` ou `a->coef = NULL;`). Cependant, le pointeur `coef` étant de type `int **`, le second niveau d'indirection pointe vers des entiers mutables. Pour rendre les valeurs protégées en lecture seule en profondeur, il faudrait qualifier le tableau comme `const int * const *coef;`.

**Q5.2 : Pourquoi refuse-t-on l'appel `mat_additionner(&a, &b, &a)` alors que, mathématiquement, $a \leftarrow a+b$ a un sens ? Que se passerait-il avec notre implémentation si on l'acceptait ?**  
> L'appel est rejeté par `verifier_parametres` car l'aliasing entre opérande d'entrée et variable de sortie viole la règle R5. Si l'on autorisait `res == a`, l'instruction initiale `*res = MATRICE_VIDE;` écraserait immédiatement la structure `a` : `a.coef` deviendrait `NULL`, entraînant la perte des adresses allouées (fuite mémoire immédiate). Dès la boucle d'addition, le déréférencement `a->coef[i][j]` tenterait d'accéder à l'adresse 0, déclenchant un plantage instantané (*Segmentation Fault*). Pour effectuer $a \leftarrow a+b$, l'utilisateur doit stocker le calcul dans une variable temporaire `tmp` puis remplacer `a`.

**Q5.3 : Combien de multiplications d'entiers effectue `mat_multiplier` pour des matrices $n \times p$ et $p \times q$ ? Combien pour deux matrices $1\,000 \times 1\,000$ ?**  
> La matrice résultante comporte $n \times q$ éléments. Pour chaque case $(i, j)$, le calcul effectue le produit scalaire d'une ligne de $A$ ($p$ éléments) par une colonne de $B$ ($p$ éléments), soit $p$ multiplications élémentaires. Le nombre total de multiplications scalaires est exactement :
> $$N = n \times p \times q$$
> Pour deux matrices de taille $1\,000 \times 1\,000$, nous avons $n = p = q = 1\,000$, soit $1\,000 \times 1\,000 \times 1\,000 = \mathbf{1\,000\,000\,000}$ (un milliard de multiplications).

**Q5.4 : Pourquoi ne suffit-il pas de calculer `int s = a + b;` puis de tester `s < a` pour détecter un dépassement ?**  
> Ce test est doublement incorrect :
> 1. En C standard, le débordement d'un entier signé est un comportement indéfini (*undefined behavior*). Les compilateurs modernes optimisant le code (avec `-O2` ou `-O3`) supposent que ce comportement ne se produit jamais et éliminent purement et simplement le test `s < a`.
> 2. Si le coefficient $b$ est négatif, l'inégalité $a + b < a$ est mathématiquement normale et toujours vraie sans qu'aucun dépassement n'ait eu lieu, provoquant de faux positifs. Notre approche garantit la détection en calculant dans un conteneur 64 bits `long long` puis en vérifiant que le résultat est dans $[ \text{INT\_MIN}, \text{INT\_MAX} ]$.

#### Sortie du test unitaire (`./test_ex3`)
```
=== Exercice 3 : addition ===
[OK]    (3.a) (2 x 3) + (3 x 2) : MAT_ERR_DIMENSIONS
[OK]    (3.d) (2 x 3) + (2 x 3) : MAT_OK
[OK]    (3.c) a + b est correct
[OK]    a et b n'ont pas ete modifiees
[OK]    (3.b) le resultat possede sa propre memoire
[OK]    (3.c) INT_MAX + 1 : MAT_ERR_DEPASSEMENT
=== Exercice 3 : multiplication ===
[OK]    (3.e) (2 x 3) x (2 x 3) : MAT_ERR_DIMENSIONS
[OK]    (3.h) (2 x 3) x (3 x 2) : MAT_OK
[OK]    (3.g) a x c = (58 64 / 139 154)
[OK]    (3.f) (3 x 2) x (2 x 3) donne une matrice 3 x 3
[OK]    a et c n'ont pas ete modifiees
[OK]    (3.g) 2 x 10^10 depasse INT_MAX : MAT_ERR_DEPASSEMENT
=== Exercice 3 : cas particuliers ===
[OK]    resultat = entree refuse, a reste intacte
[OK]    (3.f) echec d'allocation : MAT_ERR_ALLOCATION, r vide

Bilan : 14 / 14 verifications reussies.
Pensez a verifier l'absence de fuite : valgrind --leak-check=full ./test_ex3
```

---

### 4.4 Exercice 4 — Intégration dans le programme principal
*Responsable : Adji Deguène BEISSE*

#### Code implémenté dans `main.c`

```c
/* (4.a) Affichage des matrices chargées A et B */
mat_afficher("A", &a);
mat_afficher("B", &b);

/* (4.b) Calcul de l'opération demandée */
MatErreur err = addition ? mat_additionner(&a, &b, &r)
                         : mat_multiplier(&a, &b, &r);
if (err != MAT_OK) {
    fprintf(stderr, "Erreur : %s (%dx%d et %dx%d)\n",
            mat_message_erreur(err),
            a.nb_lignes, a.nb_colonnes,
            b.nb_lignes, b.nb_colonnes);
    goto nettoyage;
}

/* (4.c) Affichage de la matrice résultante */
mat_afficher(addition ? "R = A + B" : "R = A x B", &r);

/* Sauvegarde sur fichier */
if (sauvegarder(argv[4], &r) != MAT_OK)
    goto nettoyage;

/* (4.d) Clôture réussie */
printf("Résultat enregistré dans \"%s\".\n", argv[4]);
statut = EXIT_SUCCESS;

nettoyage:
    mat_detruire(&r);
    mat_detruire(&b);
    mat_detruire(&a);
    return statut;
```

#### Réponses aux questions de réflexion (Exercice 4)

**Q6.1 : Pourquoi le message d'erreur est-il affiché par `main.c` (ou ses fonctions `static`) et non par `mat_lire` ? Pensez à un programme graphique qui réutiliserait la bibliothèque.**  
> Il s'agit du principe fondamental de découplage entre logique métier et interface utilisateur. Une bibliothèque réutilisable est destinée à être intégrée dans des contextes divers : applications en ligne de commande, interfaces graphiques (GUI GTK/Qt), applications web ou serveurs d'API. Si `mat_lire` affichait des messages d'erreur directement sur `stderr` ou `stdout`, elle polluerait l'environnement hôte sans permettre à une interface graphique d'afficher une boîte de dialogue adaptée. En retournant un code d'erreur `MatErreur`, la bibliothèque laisse l'application cliente totalement maîtresse de la restitution utilisateur.

**Q6.2 : Pourquoi le résultat de `fclose` est-il testé dans `sauvegarder` mais pas dans `charger` ?**  
> Lors de l'écriture dans un fichier, les écritures physiques sur disque sont différées dans un tampon mémoire (*buffer*). L'appel à `fclose` déclenche le vidage final (*flush*) de ce tampon. Si le disque devient plein ou inaccessible à cet instant, l'échec matériel ne se révélera qu'au moment de `fclose`. Ne pas le tester en écriture pourrait faire croire à tort que le fichier a été correctement enregistré. En lecture en revanche, toutes les données utiles ont déjà été lues et validées en RAM avant la fermeture ; un éventuel échec technique de `fclose` n'altère en rien l'intégrité de la matrice chargée.

**Q6.3 : Dans le scénario 8, le calcul a réussi mais l'enregistrement a échoué. Combien de matrices faut-il libérer ? Vérifiez que votre programme le fait.**  
> Il faut libérer exactement **3 matrices** : les deux matrices sources `a` et `b` chargées depuis le disque, ainsi que la matrice résultat `r` produite par le calcul. Notre programme satisfait rigoureusement cette obligation grâce au label `nettoyage:` qui exécute inconditionnellement `mat_detruire(&r); mat_detruire(&b); mat_detruire(&a);`. La trace Valgrind du scénario 8 confirme 21 allocations et 21 libérations sans le moindre octet orphelin.

---

## 5. Vérifications mémoire (Valgrind)

L'exhaustivité des programmes et modules a été éprouvée sous Valgrind (Memcheck sous Linux x86_64).

### 5.1 Synthèse des tests unitaires

#### Bilan Valgrind — `test_ex1`
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 11 allocs, 11 frees, 1,228 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```
![Capture Valgrind test_ex1](valgrind_ex1.jpg)

#### Bilan Valgrind — `test_ex2`
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 51 allocs, 51 frees, 60,728 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```
![Capture Valgrind test_ex2](valgrind_ex2.png)

#### Bilan Valgrind — `test_ex3`
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 37 allocs, 37 frees, 1,412 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```
![Capture Valgrind test_ex3](valgrind_ex3.jpg)

### 5.2 Validation sur le programme de démonstration

#### Scénario nominal (Scénario 1 — Addition valide)
```
valgrind --leak-check=full ./demo_matrices add donnees/A.txt donnees/B.txt donnees/R.txt
```
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 22 allocs, 22 frees, 14,968 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

#### Scénarios d'erreur sous Valgrind (Là où se cachent les fuites)

**Scénario 3 — Dimensions incompatibles lors de l'addition :**
```
valgrind --leak-check=full ./demo_matrices add donnees/A.txt donnees/C.txt donnees/R.txt
```
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 14 allocs, 14 frees, 10,288 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

**Scénario 6 — Fichier source mal formé :**
```
valgrind --leak-check=full ./demo_matrices add donnees/invalide.txt donnees/B.txt donnees/R.txt
```
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 5 allocs, 5 frees, 4,600 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

**Scénario 8 — Chemin d'écriture inaccessible :**
```
valgrind --leak-check=full ./demo_matrices add donnees/A.txt donnees/B.txt zzz/R.txt
```
```
==HEAP SUMMARY:
==     in use at exit: 0 bytes in 0 blocks
==   total heap usage: 21 allocs, 21 frees, 10,872 bytes allocated
== 
== All heap blocks were freed -- no leaks are possible
== 
== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

---

## 6. Démonstration finale

Voici l'analyse détaillée de 4 scénarios caractéristiques exécutés avec `./demo_matrices`.

### Scénario 1 : Addition valide (Cas nominal)
```bash
./demo_matrices add donnees/A.txt donnees/B.txt donnees/R.txt
echo $?
```
**Sortie obtenue :**
```
A (4 x 3) :
       25       48       84
       15       33       11
       45       88       10
        0       12       -5
B (4 x 3) :
        1        2        3
        4        5        6
        7        8        9
       10       11       12
R = A + B (4 x 3) :
       26       50       87
       19       38       17
       52       96       19
       10       23        7
Résultat enregistré dans "donnees/R.txt".
```
**Code de retour :** `0`  
**Analyse :** Comportement entièrement conforme. Les matrices $A$ et $B$ sont bien chargées, le résultat $R = A + B$ est affiché avec un formatage soigné et persisté dans `donnees/R.txt`.

### Scénario 1bis : Relecture du résultat (Consistance du format)
```bash
./demo_matrices add donnees/R.txt donnees/R.txt donnees/R2.txt
echo $?
```
**Sortie obtenue :**
```
A (4 x 3) :
       26       50       87
       19       38       17
       52       96       19
       10       23        7
B (4 x 3) :
       26       50       87
       19       38       17
       52       96       19
       10       23        7
R = A + B (4 x 3) :
       52      100      174
       38       76       34
      104      192       38
       20       46       14
Résultat enregistré dans "donnees/R2.txt".
```
**Code de retour :** `0`  
**Analyse :** Ce test confirme que le fichier `R.txt` produit par `mat_ecrire` respecte rigoureusement la syntaxe acceptée par `mat_lire` sans aucune incompatibilité.

### Scénario 3 : Dimensions incompatibles pour l'addition (Erreur métier)
```bash
./demo_matrices add donnees/A.txt donnees/C.txt donnees/R.txt
echo $?
```
**Sortie obtenue :**
```
A (4 x 3) :
       25       48       84
       15       33       11
       45       88       10
        0       12       -5
B (3 x 2) :
        1        2
        3        4
        5        6
Erreur : dimensions incompatibles (4x3 et 3x2)
```
**Code de retour :** `1`  
**Analyse :** Comportement attendu. L'incompatibilité de dimensions ($4 \times 3$ et $3 \times 2$) est détectée avant toute altération. Un message précis est émis sur `stderr`, aucune écriture n'est opérée et le code de sortie est `EXIT_FAILURE` (`1`).

### Scénario 5 : Fichier source absent (Erreur système)
```bash
./demo_matrices add donnees/inexistant.txt donnees/B.txt donnees/R.txt
echo $?
```
**Sortie obtenue (sur stderr) :**
```
Erreur : impossible d'ouvrir "donnees/inexistant.txt" : No such file or directory
```
**Code de retour :** `1`  
**Analyse :** L'échec d'ouverture de fichier est correctement intercepté par `fopen`, documenté via `strerror(errno)` sur `stderr`, et le programme quitte immédiatement avec le code `1` sans provoquer de déréférencement invalide.

---

## 7. Bilan, difficultés et aides extérieures

### 7.1 Difficultés rencontrées et solutions apportées

1. **Rembobinage lors de l'échec partiel d'allocation (Étape 1.d) :**  
   *Problème :* Dans une matrice $n \times p$, lorsqu'une allocation de ligne échoue à l'indice $i$, il est tentant d'appeler directement `mat_detruire`. Or, à cet instant, la structure `Matrice` n'est pas encore initialisée et les cases de $i$ à $n-1$ du tableau `coef` contiennent des valeurs non initialisées.  
   *Solution :* Nous avons implémenté une boucle explicite de désallocation inversée : `for (int k = i - 1; k >= 0; k--) free(coef[k]);` suivie de `free(coef);`. Cette structure déterministe garantit qu'aucun pointeur indéfini n'est transmis à `free`.

2. **Dépassements arithmétiques signés dans le produit matriciel (Étape 3.g) :**  
   *Problème :* Le calcul du produit matriciel cumule des sommes de multiplications. Un contrôle naif après calcul est inopérant en C car le débordement de type signé constitue un comportement indéfini.  
   *Solution :* Nous avons converti chaque produit partiel en arithmétique 64 bits `long long p = (long long)a->coef[i][k] * b->coef[k][j];` et mis en place une garde préventive avant accumulation (`p > 0 && s > LLONG_MAX - p`), complétée par un contrôle de borne d'intervalle `[INT_MIN, INT_MAX]`.

3. **Intégration d'historiques Git divergents :**  
   *Problème :* Les membres du trinôme ayant travaillé sur des branches et commits distincts sur GitHub, une tentative de fusion initiale a retourné `fatal: refusing to merge unrelated histories`.  
   *Solution :* Nous avons aligné la branche `main` locale avec `master` via un recalage propre (`git reset --hard`) après avoir fusionné manuellement et nettoyé l'intégralité du code dans l'arbre principal.

### 7.2 Répartition du travail au sein du trinôme

- **Hady KALOGA (`informaticienC69`, Chef de groupe) :** Conception de l'architecture générale, réalisation de l'**Exercice 1** (`matrice.c`, `matrice_alloc.c`), de l'**Exercice 3** (`matrice_calcul.c`), écriture du `Makefile`, orchestration des campagnes Valgrind et coordination du compte rendu.
- **Simone Lassanadio FALL (`SIMONEFALL`) :** Réalisation de l'**Exercice 2** (`matrice_io.c`), implémentation de l'affichage formaté, des fonctions de lecture/écriture avec parseur robuste, et rédaction des questions de réflexion associées.
- **Adji Deguène BEISSE (`beisse25`) :** Réalisation de l'**Exercice 4** (`main.c`), structuration du point d'entrée, gestion du nettoyage unifié (`goto nettoyage;`), validation des 10 scénarios de démonstration et tests de non-régression.

### 7.3 Déclaration des aides extérieures

Conformément à la charte d'intégrité académique, nous déclarons avoir utilisé :
- **Documentation et manuels de référence :** Pages de manuel POSIX/Linux (`man 3 calloc`, `man 3 strtol`, `man 3 fopen`).
- **Outils d'analyse dynamique :** Valgrind Memcheck 3.22.0 sous environnement Linux pour la traque et la preuve mathématique de l'absence de fuites mémoire.
- **Assistant d'intelligence artificielle :** L'assistant IA a été utilisé comme outil de relecture croisée de la syntaxe C11, d'aide à la calibration du nombre de mots du rapport Markdown et de structuration du `Makefile`. L'ensemble des algorithmes, de la logique des pointeurs et des choix architecturaux a été pleinement compris, validé et testé par les membres du trinôme.
