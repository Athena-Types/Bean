{(z : dnum)}
{(a : (num, num, num))}

/*
    Computes a0 + a1z + a2z^2 using Horner's method.
*/

let (a0, a') = a;
let (a1, a2) = a';

let y1 = dmul z a2;
let y2 = add a1 y1;
let y3 = dmul z y2;
add a0 y3
