#!/bin/bash


SERVER_IP="${SERVER_IP:-192.168.0.99}"
SSH_USER="${SSH_USER:-meikaik}"
KEY_USER="${KEY_USER:-meikaik}"
DOCKER_VERSION="${DOCKER_VERSION:-17.05.0~ce}"

DOCKER_PULL_IMAGES=("postgres:9.6-alpine" "redis:3.2-alpine")

function configure_sudo () {
  echo "Configuring passwordless sudo..."
  scp "sudo/sudoers" "${SSH_USER}@${SERVER_IP}:/tmp/sudoers"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo chmod 440 /tmp/sudoers
sudo chown root:root /tmp/sudoers
sudo mv /tmp/sudoers /etc
  '"
  echo "done!"
}


function add_ssh_key() {
  echo "Adding SSH key..."
  cat "$HOME/.ssh/id_rsa.pub" | ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
mkdir /home/${KEY_USER}/.ssh
cat >> /home/${KEY_USER}/.ssh/authorized_keys
    '"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
chmod 700 /home/${KEY_USER}/.ssh
chmod 640 /home/${KEY_USER}/.ssh/authorized_keys
sudo chown ${KEY_USER}:${KEY_USER} -R /home/${KEY_USER}/.ssh
  '"
  echo "done!"
}

function configure_secure_ssh () {
  echo "Configuring secure SSH..."
  scp "ssh/sshd_config" "${SSH_USER}@${SERVER_IP}:/tmp/sshd_config"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo chown root:root /tmp/sshd_config
sudo mv /tmp/sshd_config /etc/ssh
sudo systemctl restart ssh
  '"
  echo "done!"
}

function configure_sources_list () {
  echo "Configuring sources.list file..."
#   ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
# sudo sed -i -r "s/^deb.+cdrom/\#debcdrom/g" /etc/apt/sources.list
# grep "jessie-backports" /etc/apt/sources.list >> /dev/null || \
# cat <<EOT | sudo tee -a /etc/apt/sources.list >> /dev/null

# deb http://ftp.debian.org/debian jessie-backports main contrib non-free
# EOT
#   '"
  scp "package-sources/sources.list" "${SSH_USER}@${SERVER_IP}:/tmp/sources.list"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo chown root:root /tmp/sources.list
sudo rm /etc/apt/sources.list
sudo mv /tmp/sources.list /etc/apt/sources.list
  '"
  echo "done!"
}

function install_docker () {
  echo "Configuring Docker v${1}..."
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
#sudo apt-get update
sudo apt-get install -y -q curl wget apt-transport-https dirmngr libapparmor1 aufs-tools ca-certificates libltdl7 git
wget -O "docker.deb https://apt.dockerproject.org/repo/pool/main/d/docker-engine/docker-engine_${1}-0~debian-stretch_amd64.deb"
sudo dpkg -i docker.deb
rm docker.deb
sudo usermod -aG docker "${KEY_USER}"
  '"
  echo "done!"
}

function docker_pull () {
  echo "Pulling Docker images..."
  for image in "${DOCKER_PULL_IMAGES[@]}"
  do
    ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'docker pull ${image}'"
  done
  echo "Docker Images: "
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'docker images'"
  echo "done!"
}

function git_init () {
  echo "Initializing git repo and hooks..."
  scp "git/post-receive/mobydock" "${SSH_USER}@${SERVER_IP}:/tmp/mobydock"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo rm -rf /var/git/mobydock.git /var/git/mobydock
sudo mkdir -p /var/git/mobydock.git /var/git/mobydock
sudo git --git-dir=/var/git/mobydock.git --bare init

sudo mv /tmp/mobydock /var/git/mobydock.git/hooks/post-receive
sudo chmod +x /var/git/mobydock.git/hooks/post-receive
sudo chown ${SSH_USER}:${SSH_USER} -R /var/git/mobydock.git /var/git/mobydock
  '"
  echo "done!"
}

function configure_firewall () {
  echo "Configuring iptables..."
  scp "iptables/rules-save" "${SSH_USER}@${SERVER_IP}:/tmp/rules-save"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo mkdir -p /var/lib/iptables
sudo mv /tmp/rules-save /var/lib/iptables
sudo chown root:root -R /var/lib/iptables
  '"
  echo "done!"
}

function provision_server () {
  configure_sudo
  echo "---"
  add_ssh_key
  echo "---"
  configure_secure_ssh
  echo "---"
  configure_sources_list
  echo "---"
  install_docker ${1}
  echo "---"
  docker_pull
  echo "---"
  git_init
  echo "---"
  configure_firewall
}

function help_menu () {
cat << EOF
Usage: ${0} (-h | -S | -u | -k | -s | -l | -d [docker_ver] | -a [docker_ver])

ENVIRONMENT VARIABLES:
   SERVER_IP        IP address to work on, ie. staging or production
                    Defaulting to ${SERVER_IP}

   SSH_USER         User account to ssh and scp in as
                    Defaulting to ${SSH_USER}

   KEY_USER         User account linked to the SSH key
                    Defaulting to ${KEY_USER}

   DOCKER_VERSION   Docker version to install
                    Defaulting to ${DOCKER_VERSION}

OPTIONS:
   -h|--help                 Show this message
   -u|--sudo                 Configure passwordless sudo
   -k|--ssh-key              Add SSH key
   -s|--ssh                  Configure secure SSH
   -l|--sources              Configure apt-get package sources
   -d|--docker               Install Docker
   -p|--docker-pull          Pull necessary Docker images
   -g|--git-init             Install and initialize git
   -f|--firewall             Configure the iptables firewall
   -a|--all                  Provision everything

EXAMPLES:
   Configure passwordless sudo:
        $ deploy -u

   Add SSH key:
        $ deploy -k

   Configure secure SSH:
        $ deploy -s

   Install Docker v${DOCKER_VERSION}:
        $ deploy -d

   Install custom Docker version:
        $ deploy -d 17.05.0~ce

   Pull necessary Docker images:
        $ deploy -p

   Install and initialize git:
        $ deploy -g

   Configure the iptables firewall:
        $ deploy -f

   Configure everything together:
        $ deploy -a

   Configure everything together with a custom Docker version:
        $ deploy -a 17.05.0~ce
EOF
}


while [[ $# > 0 ]]
do
case "${1}" in
  -u|--sudo)
  configure_sudo
  shift
  ;;
  -k|--ssh-key)
  add_ssh_key
  shift
  ;;
  -s|--ssh)
  configure_secure_ssh
  shift
  ;;
  -l|--sources)
  configure_sources_list
  shift
  ;;
  -d|--docker)
  install_docker "${2:-${DOCKER_VERSION}}"
  shift
  ;;
  -p|--docker-pull)
  docker_pull
  shift
  ;;
  -g|--git-init)
  git_init
  shift
  ;;
  -f|--firewall)
  configure_firewall
  shift
  ;;
  -a|--all)
  provision_server "${2:-${DOCKER_VERSION}}"
  shift
  ;;
  -h|--help)
  help_menu
  shift
  ;;
  *)
  echo "${1} is not a valid flag, try running: ${0} --help"
  ;;
esac
shift
done
