FROM projectoss/alpine:3.20.0

# Install security updates first
RUN apk update && apk upgrade

# Install required packages
RUN apk add --no-cache \
    ca-certificates \
    bash \
    git \
    gnupg \
    jq \
    curl \
    gettext \
    openssl \
    py3-pip \
    python3 \
    && pip3 install --no-cache-dir awscli boto3

# Set versions - update these regularly
ARG KUBECTL_VERSION="1.30.0"
ARG HELM_VERSION="3.14.4"
ARG KUBESEAL_VERSION="0.26.0"

# Install kubectl
RUN curl -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && curl -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" -o kubectl.sha256 \
    && echo "$(cat kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c \
    && chmod +x /usr/local/bin/kubectl \
    && rm kubectl.sha256

# Install Helm with verification
RUN curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" -o helm.tar.gz \
    && curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" -o helm.sha256 \
    && sha256sum -c helm.sha256 \
    && tar -xzf helm.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf linux-amd64 helm.tar.gz helm.sha256

# Install kubeseal for sealed secrets support
RUN curl -L "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" -o kubeseal.tar.gz \
    && tar -xzf kubeseal.tar.gz \
    && mv kubeseal /usr/local/bin/ \
    && chmod +x /usr/local/bin/kubeseal \
    && rm kubeseal.tar.gz

# Create non-root user for security
RUN addgroup -g 1001 runner && \
    adduser -D -u 1001 -G runner runner

# Set up directories with proper permissions
RUN mkdir -p /opt/kubernetes /opt/helm /app && \
    chown -R runner:runner /opt/kubernetes /opt/helm /app

# Environment variables
ENV KUBECONFIG="/opt/kubernetes/config"
ENV HELM_HOME="/opt/helm"
ENV XDG_CONFIG_HOME="/opt/helm"
ENV HELM_CACHE_HOME="/opt/helm/cache"
ENV PYTHONUNBUFFERED=1

# Copy files
COPY --chown=runner:runner . /app/
WORKDIR /app

# Make scripts executable
RUN chmod +x /app/entrypoint.sh /app/scripts/*.sh

# Switch to non-root user
USER runner

ENTRYPOINT ["/app/entrypoint.sh"]