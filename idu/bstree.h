//: bstree.h
//: An easy implementation of Binary Sorting Tree
//: Tip: Some of the code is copied from Brian and
//:      Rob's work "The Practice of Programming"
//: Exp4 v0.13
//: Agent2002. All rights reserved.
//: 04-12-21 04-12-21

#ifndef BSTREE_H_
#define BSTREE_H_

#ifndef DEBUG
#define DEBUG 0
#endif

#include <stdlib.h>
#include <stdio.h>

typedef struct Node {
    int value;
    struct Node* parent;
    struct Node* left;   /* lesser */
    struct Node* right;  /* greater */
} Node;

/* newnode: create new node from value */
Node* newnode(int value) {
    Node* nodep = (Node*) malloc(sizeof(Node));
    if (nodep == NULL)
        return NULL;
    nodep->value = value;
    nodep->parent = NULL;
    nodep->left  = NULL;
    nodep->right = NULL;
    return nodep;
}

/* setleft: set parentp's left child to newp */
void setleft(Node* parentp, Node* newp) {
    if (newp != NULL)
        newp->parent = parentp;
    if (parentp != NULL)
        parentp->left = newp;
}

/* setright: set parentp's right child to newp */
void setright(Node* parentp, Node* newp) {
    if (newp != NULL)
        newp->parent = parentp;
    if (parentp != NULL)
        parentp->right = newp;
}

/* resetchild: reset parentp's child from oldp to newp */
void resetchild(Node* parentp, Node* oldp, Node* newp) {
    if (newp != NULL)
        newp->parent = parentp;
    if (parentp == NULL)
        return;
    if (parentp->left == oldp)
        parentp->left = newp;
    else
        parentp->right = newp;
}

/* insert: insert newp in treep, return treep */
Node* insert(Node* treep, Node* newp) {
    if (treep == NULL)
        return newp;
    if (newp->value == treep->value)
        fprintf(stderr, "warning: insert: duplicate entry "
                        "%d ingnored.\n", newp->value);
    else if (newp->value < treep->value)
        setleft(treep, insert(treep->left, newp));
    else
        setright(treep, insert(treep->right, newp));
    return treep;
}

/* lookup: look up value in tree treep */
Node* lookup(Node* treep, int value) {
    if (treep == NULL)
        return NULL;
    if (value == treep->value)
        return treep;
    else if (value < treep->value)
        return lookup(treep->left, value);
    else
        return lookup(treep->right, value);
}

/* printinorder: print all nodes in treep in-orderly */
void printinorder(Node* treep) {
    if (treep == NULL)
        return;
    printinorder(treep->left);
    printf(" %d", treep->value);
    printinorder(treep->right);
}

/* freeall: free all nodes in tree treep */
Node* freeall(Node* treep) {
    if (treep == NULL)
        return NULL;
    treep->left  = freeall(treep->left);
    treep->right = freeall(treep->right);
    if (DEBUG)
        fprintf( stderr, "freeing node '%d'...\n", treep->value );
    free(treep);
    return NULL;
}

/* findmin: locate node with minimal value in tree treep */
Node* findmin(Node* treep) {
    if (treep == NULL)
        return NULL;
    while (1) {
        if (treep->left == NULL)
            return treep;
        treep = treep->left;
    }
    return NULL;
}

/* delnode: delete nodep from tree treep */
Node* delnode(Node* treep, Node* nodep) {
    if (treep == NULL || nodep == NULL)
        return treep;
    if (nodep->left == NULL)
        if (nodep->right == NULL) {
            if (nodep == treep)
                treep = NULL;
            resetchild(nodep->parent, nodep, NULL);
            free(nodep);
            return treep;
        }
        else { /* left == NULL and right != NULL */
            if (nodep == treep)
                treep = nodep->right;
            resetchild(nodep->parent, nodep, nodep->right);
            free(nodep);
            return treep;
        }
    else
        if (nodep->right == NULL) { /* and left != NULL */
            if (nodep == treep)
                treep = nodep->left;
            resetchild(nodep->parent, nodep, nodep->left);
            free(nodep);
            return treep;
        }
        else { /* left != NULL and right != NULL */
            Node* minp;
            minp = findmin(nodep->right);
            if (minp == nodep->right)
                setright(minp->parent, minp->right);
            else
                setleft(minp->parent, minp->right);
            nodep->value = minp->value;
            // fprintf(stderr, "minp->value: %d\n", minp->value);
            free(minp);
            return treep;
        }
}

/* dumptree: dump the shap of treep to stdout */
void dumptree(Node* treep, const char* indent) {
    static int curLevel = 0;
    int i;
    for (i = 0; i < curLevel; i++)
        printf( indent );
    if (treep == NULL) {
        printf( "[]\n" );
        return;
    }
    printf("[%d]\n", treep->value);

    if (treep->left != NULL || treep->right != NULL) {
        curLevel++;
        dumptree( treep->left, indent );
        dumptree( treep->right, indent );
        curLevel--;
    }
}

#endif /* BSTREE_H_ */
