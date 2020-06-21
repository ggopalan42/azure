#! /bin/bash
sudo snap install --dangerous --devmode az-moby-engine-cli-306_3.0.6_amd64.snap
sleep 5


sudo snap connect az-moby-engine-cli-306:docker-support
sleep 2
sudo snap connect az-moby-engine-cli-306:firewall-control
sleep 2

# sudo snap start --enable az-moby-engine-cli-306.dockerd
sleep 2

