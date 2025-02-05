{(A : ((num, num), (num, num))) (b : (num, num))}
`{}

/* 
    Suppose Ax = b where A is a 2x2 lower triangular matrix and 
    b is a vector in R^2.
    Thus, x1 = b1 / A11 and we solve for x2.
*/

let (A1, A2) = A;
let (A11, A12) = A1;
let (A21, A22) = A2;
let (b1, b2) = b;

let x1_or_none = div b1 A11; 
case x1_or_none of {
  inl (x1) => 
    dlet dx1 = !x1;
    let s1 = dmul dx1 A21;
    let s2 = sub b2 s1;
    let x2_or_none = div s2 A22;
    case x2_or_none of {
      inl (x2) => inl () (dx1, x2)
    | inr (none) => inr (dnum, num) none
    }
| inr (none) => inr (dnum, num) none
}
