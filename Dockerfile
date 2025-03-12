FROM ocaml/opam:alpine-ocaml-5.1
RUN sudo apk update && sudo apk upgrade
# Need git for opam 2.3
RUN sudo apk add git

COPY . /bean
WORKDIR /bean
RUN sudo chown -R $(whoami) .

# Initialize git
RUN sudo git init
RUN git config --global --add safe.directory .

# Install packages from opam
RUN opam-2.3 init && opam-2.3 update
RUN opam-2.3 install --deps-only . 
RUN eval $(opam-2.3 env)

# Build bean
RUN opam-2.3 exec -- dune build