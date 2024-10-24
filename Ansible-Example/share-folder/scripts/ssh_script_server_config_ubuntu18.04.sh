#!/bin/bash

sudo apt-get update

echo "current user name: $(whoami)"
echo "print working directory: $pwd"
echo "current working folder: $HOME"

##########################
SSH_TYPE=$(dpkg --list | grep ssh)
if [[ "$SSH_TYPE" == *"openssh-server"* ]]; then
	echo "################################# ssh server was installed, check version ##############################"
    ssh -V
else 	
    echo "################################### installing ssh-server #################################################################"
	sudo apt-get upgrade
	sudo apt-get install openssh-server
	# https://www.cyberciti.biz/faq/ubuntu-linux-install-openssh-server/
	sudo systemctl enable ssh --now
	sudo systemctl start ssh
	
	sudo ufw allow ssh
	sudo ufw enable
	sudo ufw status
fi
unset SSH_TYPE

############################

CURRENT_USER_NAME="$(whoami)"
#CURRENT_USER_NAME="$USER"

CURRENT_USER_HOME_DIR="$HOME"

if [ "$1" ]; then
    CURRENT_USER_NAME=$1
fi

echo "######################### storage my name to file $HOME/storageName.txt"
sudo touch $HOME/storageName.txt
sudo echo "$CURRENT_USER_NAME" | sudo tee -a $HOME/storageName.txt > /dev/null

if [ -e $HOME/sudoers.bak ]; then
    echo "######################### file $HOME/sudoers.bak is existed"
else
	echo "######################### File $HOME/sudoers.bak does not existed. Create it."
	sudo touch $HOME/sudoers.bak;
	
	sudo cp /etc/sudoers $HOME/sudoers.bak
    
	userName=`cat $HOME/storageName.txt`
	sudo rm $HOME/storageName.txt
	# https://www.cyberciti.biz/faq/linux-unix-running-sudo-command-without-a-password/
	echo "######################### modify /etc/sudoers, allow $userName can do anything in system. $userName ALL=(ALL) NOPASSWD:ALL"
	File=/etc/sudoers
	if ! sudo grep -q "$userName ALL=(ALL)" "$File" ;then
	  # sudo echo $CURRENT_USER_NAME ALL = NOPASSWD: /bin/systemctl restart httpd.service, /bin/kill >> /etc/sudoers
	  # careful with that command
	  sudo echo "#config allow for $userName user" | sudo tee -a /etc/sudoers > /dev/null
	  sudo echo "$userName ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
	fi
	unset File
	unset userName
fi

if [ $CURRENT_USER_NAME != root ] && [ $(id -u) -eq 0 ] ; then
	echo "Setting up new user..., password is the same with the username"
	id -u "$CURRENT_USER_NAME" &>/dev/null || useradd -m -d "/home/$CURRENT_USER_NAME" "$CURRENT_USER_NAME"
		
	echo "$CURRENT_USER_NAME:$CURRENT_USER_NAME" | sudo chpasswd
	# Set ownership of the home directory and subfolder to the new user
	chown -R $CURRENT_USER_NAME:$CURRENT_USER_NAME /home/$CURRENT_USER_NAME
		
	echo "User '$CURRENT_USER_NAME' created with home directory at '/home/$CURRENT_USER_NAME'."
		
	CURRENT_USER_HOME_DIR=/home/$CURRENT_USER_NAME
fi

if [ ! -d $CURRENT_USER_HOME_DIR/.ssh ]; then
  echo "$CURRENT_USER_HOME_DIR/.ssh does not exist. Create it"
  mkdir $CURRENT_USER_HOME_DIR/.ssh
fi

if [ ! -e $CURRENT_USER_HOME_DIR/.ssh/config ]; then
	 echo "######################### $CURRENT_USER_HOME_DIR/.ssh/config does not exist. Create it"
	 sudo touch $CURRENT_USER_HOME_DIR/.ssh/config
	 sudo chown -R $CURRENT_USER_NAME:$CURRENT_USER_NAME /home/$CURRENT_USER_NAME/.ssh/config 
	 sudo chmod 600 $CURRENT_USER_HOME_DIR/.ssh/config
fi

if [ ! -e $CURRENT_USER_HOME_DIR/.ssh/known_hosts ]; then
	 echo "######################### $CURRENT_USER_HOME_DIR/.ssh/known_hosts does not exist. Create it"
	 sudo touch $CURRENT_USER_HOME_DIR/.ssh/known_hosts
	 sudo chown -v $CURRENT_USER_NAME $CURRENT_USER_HOME_DIR/.ssh/known_hosts
	 sudo chmod 600 $CURRENT_USER_HOME_DIR/.ssh/known_hosts
fi

##############################
if [ -e $CURRENT_USER_HOME_DIR/.ssh/authorized_keys ]; then
	echo "######################### authorized_keys is existed. Do nothing"
else
	#sudo cat id_rsa.pub>>/home/$CURRENT_USER_NAME/.ssh/authorized_keys
	echo "######################### authorized_keys does not existed. Create it";
	# sudo touch authorized_keys
	sudo touch $CURRENT_USER_HOME_DIR/.ssh/authorized_keys
	sudo chmod 700 $CURRENT_USER_HOME_DIR/.ssh && chmod 600 $CURRENT_USER_HOME_DIR/.ssh/authorized_keys
	sudo chown -R $CURRENT_USER_NAME:$CURRENT_USER_NAME $CURRENT_USER_HOME_DIR/.ssh
fi

echo "######################### Config /etc/ssh/sshd_config to allow ssh withou password, using public key";
sudo sed -i -E "s|#?PasswordAuthentication.*|PasswordAuthentication no|g" /etc/ssh/sshd_config
sudo sed -i -E "s|#?PubkeyAuthentication.*|PubkeyAuthentication yes|g" /etc/ssh/sshd_config

sudo systemctl restart sshd

echo "Add ssh key public to ssh server if exist."
SSH_PUBLIC_KEY=""
if [ "$2" ]; then
 SSH_PUBLIC_KEY="$2"
fi

if [[ -n "$SSH_PUBLIC_KEY" ]]; then
    echo "Public key: $SSH_PUBLIC_KEY, add to $CURRENT_USER_HOME_DIR/.ssh/authorized_keys folder."
	echo "$SSH_PUBLIC_KEY" >> "$CURRENT_USER_HOME_DIR/.ssh/authorized_keys"
	sudo systemctl restart sshd
else
    echo "The variable SSH_PUBLIC_KEY=$SSH_PUBLIC_KEY is null or empty. do nothing"
fi

unset CURRENT_USER_NAME
unset SSH_PUBLIC_KEY
unset CURRENT_USER_HOME_DIR
