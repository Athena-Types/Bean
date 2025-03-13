{(x : (num, num))}
{(a : dnum)}

/*
    Computes a * x where x is in R^2.
*/

let (x0, x1) = x;

let u = dmul a x0;
let v = dmul a x1;
(u, v)
