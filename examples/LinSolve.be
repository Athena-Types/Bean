{}
{(A : ((num, num), (num, num))) (b : (num, num))}

/* 
    Computes x where Ax = b, A is a 2x2 lower triangular matrix and 
    b and x are vectors in R^2.
*/

let (a0, a1) = A;
let (a00, a01) = a0;
let (a10, a11) = a1;
let (b0, b1) = b;

let x0_or_err = div b0 a00;
case x0_or_err of {
  inl (x0) =>
    dlet d_x0 = !x0;
    let s0 = dmul d_x0 a10;
    let s1 = sub b1 s0;
    let x1_or_err = div s1 a11;
    case x1_or_err of {
      inl (x1) => inl () (d_x0, x1)
    | inr (err) => inr (dnum, num) err
    }
| inr (err) => inr (dnum, num) err
}
