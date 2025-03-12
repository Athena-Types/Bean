(lang dune 3.17)

(using menhir 3.0)

(name bean)

(generate_opam_files true)

(source
 (github Athena-Types/Bean))

(authors "Anonymous")

(maintainers "Anonymous")

(license "GPL-3.0")

(package
 (name bean)
 (synopsis "A type system for backward error analysis")
 (depends 
  (ocaml 
   (>= 5.1)) 
  (menhir
   (>= "20240715"))))
