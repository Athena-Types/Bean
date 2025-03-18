{(u : (dnum, dnum))}
{(v : (num, num))}

/* 
    Computes the inner product of two vectors in R^2,
    pushing error only onto the second vector.
*/

dlet (u1, u2) = u;
let (v1, v2) = v;

let x = dmul u1 v1;
let y = dmul u2 v2;
add x y
