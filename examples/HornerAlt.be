{(z : dnum)}
{(a0 : num) (a1 : num) (a2 : num)}

/*
    Computes a0 + a1z + a2z^2 using Horner's method.
*/

let y1 = dmul z a2;
let y2 = add a1 y1;
let y3 = dmul z y2;
add a0 y3
