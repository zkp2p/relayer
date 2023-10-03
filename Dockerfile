# Todo: Add refresh logic.
# Use the official Rust image as the base image
FROM rust:latest
ARG ZKP2P_BRANCH_NAME=sachin/integrate-relayer
ARG RELAYER_BRANCH_NAME=develop


# Update the package list and install necessary dependencies
RUN apt-get update && \
    apt install -y cmake build-essential pkg-config libssl-dev libgmp-dev libsodium-dev nasm

# Install Node.js 16.x and Yarn
ENV NODE_VERSION=16.19.0
RUN apt install -y curl
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version
RUN npm install -g yarn
RUN npm install -g typescript

# Clone and build rapidsnark
RUN  git clone https://github.com/Divide-By-0/rapidsnark /root/rapidsnark
WORKDIR /root/rapidsnark
RUN npm install
RUN git submodule init
RUN git submodule update
RUN npx task createFieldSources
RUN npx task buildPistache
RUN npx task buildProver
RUN chmod +x /root/rapidsnark/build/prover
WORKDIR /root/

# TODO: Instead we could just copy the build folder from the local machine
# COPY ./rapidsnark/build /rapidsnark/build

# Clone zk p2p repository at the latest commit and set it as the working directory
RUN git clone https://github.com/zkp2p/zk-p2p -b ${ZKP2P_BRANCH_NAME} /root/zk-p2p
WORKDIR /root/zk-p2p/circuits-circom
RUN yarn install
RUN yarn add tsx

# Pull keys from S3 (Could also fetch wasm)
RUN wget -P /root/zk-p2p/circuits-circom/build/venmo_send https://zk-p2p.s3.amazonaws.com/v2/v0.0.6/venmo_send/venmo_send.zkey --quiet
# RUN wget -P circuits-circom/build/venmo_receive https://zk-p2p.s3.amazonaws.com/v2/v0.0.6/venmo_receive/venmo_receive.zkey --quiet
# RUN wget -P circuits-circom/build/venmo_registration https://zk-p2p.s3.amazonaws.com/v2/v0.0.6/venmo_registration/venmo_registration.zkey --quiet


# Clone the relayer repository at the latest commit and set it as the working directory
RUN git clone --branch ${RELAYER_BRANCH_NAME} --single-branch https://github.com/zkp2p/relayer /root/relayer
WORKDIR /root/relayer
# Ask aayush why twice?
# RUN cargo build --target x86_64-unknown-linux-gnu
# RUN cargo build --target x86_64-unknown-linux-gnu --release

# Build for any AWS machine
# Do we need to build debug for prod?

# These commands are not required unless we want to run the relayer
# RUN cargo build --target x86_64-unknown-linux-gnu     
# RUN cp /root/relayer/target/x86_64-unknown-linux-gnu/debug/relayer /root/relayer/target/debug/
# RUN cargo build --target x86_64-unknown-linux-gnu --release
# RUN cp /root/relayer/target/x86_64-unknown-linux-gnu/release/relayer /root/relayer/target/release/

# Make necessary files executable
RUN chmod +x /root/relayer/src/circom_proofgen.sh

# Install pytho, pip and requirements to run coordinator.py
RUN apt-get install -y python3 python-is-python3 python3-pip python3-venv
RUN python3 -m venv /venv
# Activate the virtual environment and install requirements
RUN /venv/bin/pip install --no-cache-dir -r /root/relayer/requirements.txt

# Copy .env.example to .env
RUN cp /root/relayer/.env.example /root/relayer/.env

# Remember to setup aws credentials in modal environment
