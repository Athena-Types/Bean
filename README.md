Bean: Backward Error Analysis
=====
This is the artifact for Bean, a prototype implementation of the type system and floating-point backward error analysis tool described in the paper **Bean: A Language for Backward Error Analysis**. It implements the algorithm given in Section 5.1. 

The examples given in Section 4 can be found under `examples/`. The benchmarks from Section 5.2 can be found under `benchmarks/`.

The type checker is based on the implementation due to Arthur Azevedo de Amorim and co-authors [1].

[1] Arthur Azevedo de Amorim, Marco Gaboardi, Emilio Jesús Gallego Arias, and Justin Hsu. 2014. Really Natural Linear Indexed Type Checking. In Proceedings of the 26nd 2014 International Symposium on Implementation and Application of Functional Languages (IFL '14). Association for Computing Machinery, New York, NY, USA, Article 5, 1–12. https://doi.org/10.1145/2746325.2746335

## Getting started 
Bean can be built manually or using the provided Docker image.

### Build with Docker

If you have [Docker](https://docs.docker.com/engine/install/), in the `bean` directory, run
```
docker build -t bean .
```
After the Docker image builds, you can enter a TTY with
```
docker run -it --rm bean
```

### Build manually

This manual build has been tested on `macOS 15.4`.
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

Build Bean via `dune`:
```
dune build
```

## Running a Bean program

Type check an example with the following command:
```
dune exec -- bean examples/InnerProduct.be
```
- Turn on debug output with the flag `--debug` or `-d`.
- Disable unicode printing with the flag `--disable-unicode`.
- Set unit roundoff to `2^(-n)` with the flag `--unit-roundoff <n>` or `-u <n>`. Without this flag, we give the backward error bounds in terms of `ε`, where `ε = u / (1 - u)` and `u` is unit roundoff.

For example, run the `InnerProduct` Bean program with IEEE 754 double precision arithmetic as follows: 
```
dune exec -- bean examples/InnerProduct.be -u 53
```

The program looks like this:
```
{(u : (dnum, dnum))}
{(v : (num, num))}

/* 
    Computes the inner product of two vectors in R^2.
*/

dlet (u1, u2) = u;
let (v1, v2) = v;

let x = dmul u1 v1;
let y = dmul u2 v2;
add x y
```
Bean programs start with two lists of input variables: those that are *discrete* followed by those that are *linear*. The sole discrete input to `InnerProduct` is `u : (dnum, dnum)` while the sole linear input is `v : (num, num)`.
In a nutshell, this means that `u` and `v` are real vectors in ℝ²; however, `v` may have backward error while `u` may not.

The output is:
```
[General] Type of the program: ℝ
[General] Inferred linear context:
          v :[2.22e-16] (ℝ ⊗ ℝ)
Execution time: 0.000878s
```
The return type of `InnerProduct` is `ℝ`. 
The inferred context tells us that our input vector `v` has a backward error bound of `2.22e-16`.

**This means that there exists a vector $\tilde{v}$, where $\max_{i=1,2}|\ln(v_i/\tilde{v}_i)|\leq 2.22\cdot 10^{-16}$, such that $u\cdot\tilde{v}=$`InnerProduct u v`.**

Note that for vectors and matrices, we report the maximum componentwise backward error bound. 

## Running benchmarks
To run the benchmarks given in Section 5.2 of the paper, use the provided Makefile. Run 
```
make small
```
in the `bean` directory to run the benchmarks which take just a few seconds to run. The output will be piped to a file, `benchmarks.txt`. Run
```
make all
```
to run all the benchmarks. Note that this make take several minutes. The largest benchmark took us about 16 minutes to complete. Run
```
make clean
```
to remove the `benchmarks.txt` file and other generated Dune files.

## Writing a Bean program

Bean assumes the interpretation of the numeric type `num` as the set of real numbers ℝ with the relative precision (RP) metric given in Section 2 of the paper. 
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
    let x = e; f                       let-binding, where e is linear
    let x : T = e; f                   let-binding with type annotation
    dlet x = e; f                      let-binding, where e is discrete
    dlet x : DT = e; f                 let-binding with type annotation
    op a b                             op in (add, mul, sub, div, dmul), a and b are variables
```
- **Sequencing**: All computations are explicitly sequenced by let-bindings using the syntax `let x = e; f`. 

- **Pairs**: The syntax for tensor pairs $− \otimes −$ is `(-, -)` and the syntax for the type is also `(-, -)`. 

- **Discrete and linear inputs**: At the beginning of our programs, we write `{(ID1 : DType1) (ID2 : DType2)}` to denote the 
context of discrete variables. Next, we write `{(ID3 : Type1) (ID4 : Type2)}` to denote the context of linear variables.
All variable names must be distinct and if one context is empty, you must still include the empty braces `{}`.

- **Primitive Operations**: The type signature and name of each primitive operation is given below. 
    
    1. Addition `add : num -> num -> num`
    2. Multiplication `mult : num -> num -> num`
    3. Division `div : num -> num -> num + unit`
    4. Subtraction `sub : num -> num -> num`
    5. Discrete multiplication `dmul : dnum -> num -> num`

