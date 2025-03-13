{(z : dnum)}
{(a0 : num) (a1 : num) (a2 : num)}

/* 
    Naively evaluates the polynomial a0 + a1z + a2z^2.
*/

let y1 = dmul z a1;
let y2' = dmul z a2;
let y2 = dmul z y2';

let x = add a0 y1;
add x y2
