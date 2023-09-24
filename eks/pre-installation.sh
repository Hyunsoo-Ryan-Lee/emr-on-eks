#!/bin/bash

sudo apt-get update
sudo apt-get upgrade -y

# eksctl install
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin

# kubectl install
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.17/2023-08-16/bin/linux/amd64/kubectl
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.17/2023-08-16/bin/linux/amd64/kubectl.sha256
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc

# awscli2 install
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip
unzip awscliv2.zip
sudo ./aws/install
sleep 2
sudo rm -rf ./awscliv2.zip
echo "EKSCTL VERSION : $(eksctl --version)"
echo "KUBECTL VERSION : $(kubectl version)"
echo "AWSCLI2 VERSION : $(aws --version)"

