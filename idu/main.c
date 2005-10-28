//: main.c
//: Main file for this project.
//: Exp4 v0.13
//: Agent2002. Copyright 1984-2004.
//: 04-12-21 04-12-30

#include <stdlib.h>
#include <stdio.h>

#define DEBUG 1
#include "bstree.h"

/* getval: read an integer value from stdin */
int getval(void) {
    int val;
    scanf("%d", &val);
    return val;
}

int main(void) {
    Node* treep = NULL;
    Node* p;
    int val;

    printf("Enter the sequence(ended by -1):\n ");
    while ((val = getval()) != -1)
        treep = insert(treep, newnode(val));

    printf("The in-order sequence is:\n");
    printinorder(treep);

    printf("\nThe shape of the tree is:\n");
    dumptree(treep, "    ");

    printf("\nEnter the integer you want to delete:\n ");
    val = getval();
    p = lookup(treep, val);
    if (p == NULL)
        fprintf(stderr, "Warning: integer %d not found.\n", val);
    else {
        treep = delnode(treep, p);
        printf("In-order sequence after deletion is:\n");
        printinorder(treep);
        printf("\n");
    }

    printf("The shape of the tree after deletion is:\n");
    dumptree(treep, "    ");
    printf("\n");
    treep = freeall(treep);
    return 0;
}
