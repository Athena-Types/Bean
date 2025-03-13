{(z : dnum)}
{(a : (num, num, num))}

/* 
    Naively evaluates the polynomial a0 + a1z + a2z^2.
*/

let (a0, a') = a;
let (a1, a2) = a';

let y1 = dmul z a1;
let y2' = dmul z a2;
let y2 = dmul z y2';

let x = add a0 y1;
add x y2
