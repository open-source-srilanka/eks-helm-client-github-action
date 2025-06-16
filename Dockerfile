# Use the specified Alpine base image
FROM projectoss/alpine:3.14

# Set the KUBECONFIG environment variable to define where kubectl will look for its config file
ENV KUBECONFIG="/opt/kubernetes/config"

# Install necessary packages:
# ca-certificates: For validating SSL/TLS connections
# bash: Shell environment
# git: For cloning Git repositories, potentially private Helm charts
# gnupg: For verifying signed Helm charts or other secured assets (already present, ensuring it's there)
# jq: A lightweight and flexible command-line JSON processor
# py-pip: Python package installer, used for awscli
# curl: Tool for transferring data with URL syntax (already present, ensuring it's there)
# gettext: GNU gettext for internationalization (already present)
RUN apk add --no-cache ca-certificates bash git gnupg jq py-pip \
    && apk add --update -t deps curl gettext \
    && pip install awscli

# Define argument for Kubernetes client (kubectl) version
# Updated to a more recent stable version for better compatibility with newer EKS clusters
ARG K8_VERSION="1.30.2"
# Download and install kubectl
RUN curl -s -L https://dl.k8s.io/release/v${K8_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Define argument for Helm version
# Updated to the latest stable version for Helm 3
ARG HELM_VERSION="3.14.4"
# Download and install Helm
RUN curl -s -L https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

# Define argument for AWS IAM Authenticator version
# Updated to a more recent stable version
ARG IAM_AUTHENTICATOR_VERSION="0.6.20"
# Download, make executable, and move aws-iam-authenticator
RUN curl -o aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${IAM_AUTHENTICATOR_VERSION}_linux_amd64 \
    && chmod +x ./aws-iam-authenticator \
    && mv ./aws-iam-authenticator /usr/local/bin

# Clean up APK cache to reduce image size
RUN rm -rf /var/cache/apk/*

# Create directories for Kubernetes config and Helm, and set appropriate permissions
# These directories are used for storing configurations and cache
RUN mkdir -p /opt/kubernetes && chmod a+rwx /opt/kubernetes && mkdir -p /opt/helm && chmod a+rwx /opt/helm

# Set Helm environment variables for cache and config home
ENV HELM_HOME="/opt/helm"
ENV XDG_CONFIG_HOME="/opt/helm"
ENV HELM_CACHE_HOME="/opt/helm/cache"

# Set working directory
WORKDIR /

# Copy the entire context into the container. This should include entrypoint.sh and config.template
ADD . .

# Make the entrypoint script executable
RUN chmod +x entrypoint.sh

# Set the entrypoint for the Docker container
ENTRYPOINT [ "/entrypoint.sh" ]
