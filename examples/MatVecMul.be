{(v : (dnum, dnum))}
{(M : ((num, num), (num, num)))}

/*
    Computes Mv, where M is a 2x2 matrix and 
    v is a vector in R^2.
*/

let (m0, m1) = M;
dlet (v0, v1) = v;

/* let u0 = InnerProduct m0 v */ 
let (m00, m01) = m0;
let x0 = dmul v0 m00;
let x1 = dmul v1 m01;
let u0 = add x0 x1;

/* let u1 = InnerProduct m1 v */ 
let (m10, m11) = m1;
let y0 = dmul v0 m10;
let y1 = dmul v1 m11;
let u1 = add y0 y1;

(u0, u1)
