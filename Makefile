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
	rm -f *.o test_ex1 test_ex2 test_ex3 demo_matrices test_ex1.exe test_ex2.exe test_ex3.exe demo_matrices.exe test_ex2_sortie.txt R.txt R2.txt

.PHONY: all clean

