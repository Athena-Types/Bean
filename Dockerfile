FROM ocaml/opam:alpine-3.17-ocaml-5.1
# RUN sudo apk update && sudo apk upgrade

# installing basic packages
# RUN sudo apk add --no-cache wget

# FROM init-opam AS ocaml-base
# COPY . Bean
# RUN sudo apk add bash bash-doc bash-completion
# WORKDIR Bean

# FPTAYLOR
# RUN opam init --disable-sandboxing 
# WORKDIR ./examples/FPTaylor
# RUN sudo mkdir FPTaylor-0.9.4 \
# 	&& sudo tar -xzf v0.9.4.tar.gz -C FPTaylor-0.9.4
# WORKDIR ./FPTaylor-0.9.4
# RUN opam install num && eval $(opam env) && sudo make all
# WORKDIR ../../../

# GAPPA
# RUN sudo apk add --no-cache boost-dev \
# 	&& sudo apk add gmp-dev && sudo apk add mpfr-dev
# WORKDIR ./examples/Gappa
# RUN sudo tar -xzf gappa-1.4.2.tar.gz
# WORKDIR ./gappa-1.4.2/
# RUN sudo ./configure \
# 	&& sudo ./remake && sudo ./remake install
# WORKDIR ../../../

# Bean
RUN opam install --deps-only . \
	&& eval $(opam env) \
	&& dune build 