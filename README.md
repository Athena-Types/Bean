Bean: Backward Error Analysis
=====
This is the artifact for `bean`, a prototype implementation of the type system and floating-point backward error analysis tool described in the paper [Bean: A Language for Backward Error Analysis](https://arxiv.org/abs/2501.14550). It implements the algorithm from Section 5.1.

The examples shown in Section 4 can be found under `examples/`. The benchmarks from Section 5.2 can be found under `examples/large/`.

The type checker is based on the implementation due to Arthur Azevedo de Amorim and co-authors [1].

[1] Arthur Azevedo de Amorim, Marco Gaboardi, Emilio Jesús Gallego Arias, and Justin Hsu. 2014. Really Natural Linear Indexed Type Checking. In Proceedings of the 26nd 2014 International Symposium on Implementation and Application of Functional Languages (IFL '14). Association for Computing Machinery, New York, NY, USA, Article 5, 1–12. https://doi.org/10.1145/2746325.2746335

## Getting started 
`bean` can be built manually or using the provided Docker image.

### Build via Docker

If you have [Docker](https://docs.docker.com/engine/install/), in the `bean` directory, run
```
docker build -t bean .
```
After the Docker image builds, you can enter a TTY with
```
docker run -it --rm bean
```

### Build manually

First, get `opam >= 2.3` [here](https://opam.ocaml.org/doc/Install.html). 
You need `ocaml >= 5.1` plus `dune >= 3.17` and `menhir >= 20240715`. 
Install them with 
```
opam install [package]
```
or, in the `bean` directory, you can obtain everything with
```
opam install --deps-only .
```

Build `bean` via `dune`:
```
dune build
```

## Running a Bean program

Type check an example with the following command:
```
dune exec -- bean examples/EXAMPLE.be
```
Turn on debug output with the flag `--debug` or `-d`, and 
disable unicode printing with the flag `--disable-unicode`.

For example, run the `InnerProduct` Bean program as follows: 
```
dune exec -- bean examples/InnerProduct.be
```

The program looks like this:
```
{(v : (num, num))}
{(u : (dnum, dnum))}

/* 
    Computes the inner product of two vectors in R^2.
*/

dlet (u1, u2) = u;
let (v1, v2) = v;

let x = dmul u1 v1;
let y = dmul u2 v2;
add x y
```

`bean` programs start with a list of input variables which may be *linear* or *discrete*. 
The sole linear input to `InnerProduct` is `v : (num, num)` and the sole discrete input is `u : (dnum, dnum)`.
This means that `u` and `v` are real vectors in ℝ²; however, `v` may have backward error while `u` may not.

The output is:
```
[General] Type of the program: ℝ
[General] Inferred linear context:
          v :[2.22e-16] (ℝ ⊗ ℝ)
Execution time: 0.000878s
```
The return type of `InnerProduct` is `ℝ`. 
The inferred context tells us that our input vector `v` has a backward error bound of `2.22e-16`.

**This means that there exists a vector $\tilde{v}$, where $|\ln(v/\tilde{v})|\leq 2.22\cdot 10^{-16}$, such that $\tilde{v}\cdot u=$`InnerProduct v u`.**

We assume the IEEE 754 double precision standard, with a unit roundoff of `2e-53`, though Bean may be instantiated for other values.
Note that for vectors and matrices, we report the maximum element-wise backward error bound. 

## Writing a Bean program

`bean` assumes the interpretation of the numeric type `num` as the set of real numbers $\mathbb{R}$ with the relative precision (RP) metric given in Section 2 of the paper. 
Under this assumption, Bean can generate sound relative error bounds using the analysis described by Olver [44]. 
Soundness of the error bounds inferred by Bean is guaranteed by Section 6.2 of the paper. 

### Syntax

The syntax of Bean, detailed in Section 3 of the paper, is as follows. 

```
DT ::=                                 DISCRETE TYPES
    dnum                               discrete numeric type
    (DT, DT)                           discrete tensor product
    DT + DT                            discrete sum type

T ::=                                  TYPES
    DT                                 discrete types
    ()                                 single-valued unit type
    num                                numeric type
    (T, T)                             tensor product
    T + T                              sum type

v, w ::=                               VALUES
    ()                                 value of unit type
    a                                  variables
    (v, w)                             tensor pairs
    inl v                              injection into sum
    inr v                              injection into sum
    !x                                 !-constructor, where x is linear

e, f ::=                               EXPRESSIONS
    v                                  values
    let (x, y) = v; e                  linear tensor destructor
    dlet (x, y) = v; e                 discrete tensor destructor
    case v {inl x => e | inr x => f}   case analysis
    let x = e; f                       monadic sequencing, where e is linear
    let x : T = e; f                   monadic sequencing with type annotation
    dlet x = e; f                      monadic sequencing, where e is discrete
    dlet x : DT = e; f                 monadic sequencing with type annotation
    op a b                             op in (add, mul, sub, div, dmul), a and b are variables
```
- **Sequencing**: All computations are explicitly sequenced by let-bindings using the syntax `let x = v; e`. 

- **Pairs**: The syntax for tensor pairs $− \otimes −$ is `(-, -)` and the syntax for the type is also `(-, -)`. 

- **Linear and discrete inputs**: At the beginning of our programs, we write `{(ID1 : Type1) (ID2 : Type)}` to denote the 
context of linear variables. Next, we write `{(ID3 : DType) (ID4 : DType)}` to denote the context of discrete variables.
All variable names must be distinct and if one context is empty, you must still include the empty braces `{}`.

- **Primitive Operations**: The type signature and name of each primitive operation is given below. 
    
    1. Addition `add : num -> num -> num`
    2. Multiplication `mult : num -> num -> num`
    3. Division `div : num -> num -> num + unit`
    4. Subtraction `sub : num -> num -> num`
    5. Discrete multiplication `dmul : dnum -> num -> num`

