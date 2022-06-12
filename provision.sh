#!/bin/bash
# This script does not require any dependencies

# An explanation of why we set these options at script startup:
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -euo pipefail

# Name of the user to create and grant privileges to. By default, this is `bw`, but can be set 
# as the first argument of the `provision.sh` script if required.
# https://stackoverflow.com/questions/9332802
USERNAME_OF_ACCOUNT=${1:-bw}

# --------------------------------------------------------------------------------------------
# Step 1: Setup user
#
# Create a user, add them to the sudo and www-data groups, then immediately delete and expire 
# any password and force a change on first login. Additionally, copy any authorized keys 
# available in the DO console over to the sudo user and set the permissions on the `.ssh` 
# directory.
#
# Non-interactive user additions: https://askubuntu.com/questions/94060
# More info: https://unix.stackexchange.com/questions/79909
# More info: https://www.digitalocean.com/community/tutorials/automating-initial-server-setup-with-ubuntu-18-04
# --------------------------------------------------------------------------------------------
useradd --create-home --shell "/bin/bash" --groups sudo,www-data "${USERNAME_OF_ACCOUNT}"
passwd --delete $USERNAME_OF_ACCOUNT
chage --lastday 0 $USERNAME_OF_ACCOUNT

# --------------------------------------------------------------------------------------------
# Step 2: Configure SSH
# 
# Create and configure permissions to the `.ssh` directory in the user's home directory, and 
# make alterations to `/etc/ssh/sshd_config` to provide a more secure SSH experience.
#
# https://askubuntu.com/questions/701684
# --------------------------------------------------------------------------------------------
HOME_DIR="$(eval echo ~${USERNAME_OF_ACCOUNT})"
mkdir --parents "${HOME_DIR}/.ssh"
cp /root/.ssh/authorized_keys "${HOME_DIR}/.ssh"

chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown --recursive "${USERNAME_OF_ACCOUNT}":"${USERNAME_OF_ACCOUNT}" "${HOME_DIR}/.ssh"

sed -i '/^PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config
sed -i '/^PasswordAuthentication/s/yes/no/' /etc/ssh/sshd_config
sed -i '/^ChallengeResponseAuthentication/s/yes/no/' /etc/ssh/sshd_config

# --------------------------------------------------------------------------------------------
# Step 3: Set permissions of /var/www
# --------------------------------------------------------------------------------------------
sudo mkdir /var/www
sudo chmod 775 -R /var/www
sudo chown -R $USERNAME_OF_ACCOUNT /var/www

# --------------------------------------------------------------------------------------------
# Step 4: Install and run stock `fail2ban`
# --------------------------------------------------------------------------------------------
sudo apt-get update
sudo apt-get install --yes fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# --------------------------------------------------------------------------------------------
# Step 5: Setup a swapfile
# --------------------------------------------------------------------------------------------
sudo fallocate -l 4G /swapfile && ls -lh /swapfile
sudo chmod 0600 /swapfile && ls -lh /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile && sudo swapon --show
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudo tee -a /etc/fstab

# --------------------------------------------------------------------------------------------
# Step 6: Secure shared memory
# --------------------------------------------------------------------------------------------
echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudo tee -a /etc/fstab

# --------------------------------------------------------------------------------------------
# Step 7: Install NGINX
# --------------------------------------------------------------------------------------------
sudo apt-get update
sudo apt install --yes nginx
sudo ufw allow 'Nginx HTTP' && sudo ufw allow 'Nginx HTTPS'
sudo systemctl restart nginx

# --------------------------------------------------------------------------------------------
# Step 8: Install Docker
#
# Information on docker installation: https://docs.docker.com/engine/install/ubuntu/
# Docker post-installation steps: https://docs.docker.com/engine/install/linux-postinstall/
# --------------------------------------------------------------------------------------------
sudo apt-get update
sudo apt-get --yes install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install --yes docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo docker run hello-world

# Only add a group if it does not exist
sudo getent group docker || sudo groupadd docker
sudo usermod -aG docker $USERNAME_OF_ACCOUNT

sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# --------------------------------------------------------------------------------------------
# Step 9: Enabled unnattended updates
#
# https://www.digitalocean.com/community/tutorials/recommended-security-measures-to-protect-your-servers#unattended-updates
# --------------------------------------------------------------------------------------------
sudo apt install --yes unattended-upgrades

# --------------------------------------------------------------------------------------------
# Step 10: Appropriately configure ufw
# --------------------------------------------------------------------------------------------
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

# --------------------------------------------------------------------------------------------
# Step 11: restart and reboot any affected services
# --------------------------------------------------------------------------------------------
sudo systemctl restart sshd