FROM projectoss/alpine:3.14

ENV KUBECONFIG="/opt/kubernetes/config"

RUN apk add --no-cache ca-certificates bash git gnupg jq py-pip \
    && apk add --update -t deps curl gettext \
    && pip install awscli

ARG K8_VERSION="1.27.1"
RUN curl -s -L https://dl.k8s.io/release/v${K8_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl  

ARG HELM_VERSION="3.12.3"
RUN curl -s -L https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm 
    
ARG IAM_AUTHENTICATOR_VERSION="0.6.11"
RUN curl -o aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${IAM_AUTHENTICATOR_VERSION}_linux_amd64 \
    && chmod +x ./aws-iam-authenticator \
    && mv ./aws-iam-authenticator /usr/local/bin

RUN rm -rf /var/cache/apk/* 

RUN mkdir -p /opt/kubernetes && chmod a+rwx /opt/kubernetes && mkdir -p /opt/helm && chmod a+rwx /opt/helm

ENV HELM_HOME="/opt/helm"

ENV XDG_CONFIG_HOME="/opt/helm" 

ENV HELM_CACHE_HOME="/opt/helm/cache"

WORKDIR /

ADD . .

RUN chmod +x entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]