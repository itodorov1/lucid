#!/bin/bash

#Create a systemd service definition
cat << 'EOF' > lucidlink.service
[Unit]
Description=Lucidlink daemon
After=network.target
StartLimitIntervalSec=0
Requires=ufw.service

[Service]
Type=simple
Restart=on-abort
RestartSec=5
User=root
EnvironmentFile=/etc/lucidlink.conf
ExecStart=/bin/bash -c 'printenv PASSWORD | /usr/bin/lucid daemon --fs $FS --rest-endpoint $ENDPOINT --user $LLUSER'
ExecStop=/usr/bin/lucid exit

[Install]
WantedBy=multi-user.target
EOF

#Create a config file for the application
cat << 'EOF' > lucidlink.conf
FS=test1.lucid
LLUSER=testuser
PASSWORD=removedremoved
ENDPOINT=127.0.0.1:7778
EOF

#Copy the service and config files where they need to go
sudo cp lucidlink.service /etc/systemd/system/lucidlink.service
sudo cp lucidlink.conf  /etc/lucidlink.conf

#Refresh the list of packages in the official repos
sudo apt update

#Download the lucidlink client and install it
wget https://d3il9duqikhdqy.cloudfront.net/latest/lin64/lucid_2.0.3792_amd64.deb
sudo dpkg -i lucid_2.0.3792_amd64.deb
#Fix broken package dependencies
sudo apt --fix-broken install -y

#Reload the systemd daemon so it sees the new service that was created by copying the service file
sudo systemctl daemon-reload

#Enable unattended upgrades
sudo dpkg-reconfigure -pmedium unattended-upgrades
#Immediately update the packages to the lasted available versions
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt upgrade -y
#Enable the unattended upgrades service
sudo systemctl restart unattended-upgrades.service

#Restart services that required a restart, which was supressed during the previous steps
sudo needrestart -r a

#
sudo ufw allow 22
sudo ufw --force enable
#I probably won't be adding ssh keys like that in a prod system and would be more explicit about the user where they are added
sudo echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIILl48YbSydGQMy4ju3zWTAT8ZmWEGL5jWItXXEtbEZ6 des@tower' > ~/.ssh/authorized_keys

sudo sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
#sudo sed 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

#Restart the sshd daemon to apply the changes from above
sudo systemctl reload sshd

#Start the lucidlink service after the previous changes are applied
sudo systemctl restart lucidlink
