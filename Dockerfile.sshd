FROM alpine:3.7

ARG KUBECTL_VERSION=v1.9.0

EXPOSE 22

RUN apk add --no-cache \
    bash               \
    ca-certificates    \
    curl               \
    linux-pam          \
    openssl            \
    openssh-server-pam \
 && curl -o /usr/local/bin/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && mkdir -p /etc/ssh/keys

CMD ["/usr/sbin/sshd", "-D"]
