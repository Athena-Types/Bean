{(v : (dnum, dnum)) (a : dnum) (b : dnum)}
{(M : ((num, num), (num, num))) (u : (num, num))}

/* 
    Computes aMv + bu where M is a 2x2 matrix and
    u and v are vectors in R^2.
*/

/* let x = MatVecMul M v */
let (m0, m1) = M;
dlet (v0, v1) = v;

let (m00, m01) = m0;
let w0 = dmul v0 m00;
let w1 = dmul v1 m01;
let x0 = add w0 w1;

let (m10, m11) = m1;
let s0 = dmul v0 m10;
let s1 = dmul v1 m11;
let x1 = add s0 s1;

/* let y = ScaleVec b u */
let (u0, u1) = u;
let y0 = dmul b u0;
let y1 = dmul b u1;

/* SVecAdd a x y */
let t0 = dmul a x0;
let t1 = dmul a x1;
let r0 = add t0 y0;
let r1 = add t1 y1;
(r0, r1)
