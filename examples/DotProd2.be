{}
{(x : (num, num)) (y : (num, num))}

/* 
    Dot product of vectors x and y in R^2.
*/

let (x0, x1) = x;
let (y0, y1) = y;

let v = mul x0 y0;
let w = mul x1 y1;
add v w
