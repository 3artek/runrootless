FROM debian:9 AS proot
RUN apt-get update && apt-get install -q -y build-essential git libseccomp-dev libtalloc-dev
ADD proot/PRoot /PRoot
RUN cd PRoot/src && make && mv proot / && make clean

FROM golang:1.9-alpine AS runc
RUN apk add --no-cache git g++ linux-headers
RUN git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc \
  && cd /go/src/github.com/opencontainers/runc \
  && git checkout -q e6516b3d5dc780cb57a976013c242a9a93052543 \
  && go build -o /runc .

FROM golang:1.9-alpine AS runrootless
COPY . /go/src/github.com/AkihiroSuda/runrootless/
RUN go build -o /runrootless github.com/AkihiroSuda/runrootless

FROM alpine:3.7
RUN adduser -u 1000 -D user
COPY --from=proot /proot /home/user/.runrootless/runrootless-proot
COPY --from=runc /runc /home/user/bin/runc
COPY --from=runrootless /runrootless /home/user/bin/runrootless
COPY ./examples /home/user/examples
RUN mkdir /home/user/run
RUN chown -R user /home/user
USER user
WORKDIR /home/user
ENV PATH=/home/user/bin:$PATH
# we avoid using /run/user/1000, as container runtime (e.g. containerd) may mount empty tmpfs on /run
ENV XDG_RUNTIME_DIR=/home/user/run
# note: --privileged is required to run this container: https://github.com/opencontainers/runc/issues/1456
