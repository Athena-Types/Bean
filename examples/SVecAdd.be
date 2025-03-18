{(a : dnum)}
{(x : (num, num)) (y : (num, num))}

/* 
    Computes ax + y where x and y are vectors in R^2.
*/

/* let (x0, x1) = ScaleVec a x */
let (x0', x1') = x;
let x0 = dmul a x0';
let x1 = dmul a x1';

let (y0, y1) = y;

let u = add x0 y0;
let v = add x1 y1;
(u, v)
