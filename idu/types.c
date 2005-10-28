#include <stdio.h>

int main() {
    {
        short a, b;
        a = 3; b = 4;
        a += 3;
        b = a - 5;
        b = a * 3;
        b = a / 3;
        b = a % 6;
        b = a << 3;
        b = a >> 2;
    }
    {
        float a, b;
        a = 3; b = 4;
        a += 3;
        b = a - 5;
        b = a * 3;
        b = a / 3;
    }
    {
        double a, b;
        a = 3; b = 4;
        a += 3;
        b = a - 5;
        b = a * 3;
        b = a / 3;
    }
    return 0;
}
