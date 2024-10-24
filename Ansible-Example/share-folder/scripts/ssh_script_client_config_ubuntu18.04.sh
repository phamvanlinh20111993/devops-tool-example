#!/bin/bash

sudo apt-get update

############
SSH_TYPE=$(dpkg --list | grep ssh)
if [[ "$SSH_TYPE" == *"openssh-client"* ]]; then
	echo "################################# ssh client was installed ##############################"
    ssh -V
else 	
    echo "################################### installing ssh-client #################################################################"
	sudo apt-get upgrade
	sudo apt-get install openssh-client
	sudo systemctl enable ssh --now
	sudo systemctl start ssh
	
	sudo ufw allow ssh
	sudo ufw enable
	sudo ufw status
fi
unset SSH_TYPE

echo "current user name: $(whoami)"
echo "print working directory: $pwd"
echo "current working folder: $HOME"

REMOTE_HOST_NAME=34.126.75.224
if [ "$1" ]; then
  REMOTE_HOST_NAME=$1
fi

REMOTE_USER=vagrant
if [ "$2" ]; then
 REMOTE_USER=$2
fi

CUSTOM_KEY_PATH=""
if [ "$3" ]; then
 CUSTOM_KEY_PATH=$3
fi

CUSTOM_KEY_NAME=""
if [ "$4" ]; then
 CUSTOM_KEY_NAME=$4
fi

CURRENT_USER=$USER

CURRENT_USER_HOME_DIR=$HOME

#/bin/bash
if [ $(id -u) -eq 0 ] || [ $USER == root ] ; then

	if [ $REMOTE_USER == root ] ; then
	  echo "This setting to root user, we'ver already root user, do nothing"
	else 
	    echo "Setting up new user..., password is the same with the username"
		id -u "$REMOTE_USER" &>/dev/null || useradd -m -d "/home/$REMOTE_USER" "$REMOTE_USER"
		
		echo "$REMOTE_USER:$REMOTE_USER" | sudo chpasswd
		# Set ownership of the home directory and subfolder to the new user
		chown -R $REMOTE_USER:$REMOTE_USER /home/$REMOTE_USER
		
		echo "User '$REMOTE_USER' created with home directory at '/home/$REMOTE_USER'."
		
		CURRENT_USER=$REMOTE_USER
		CURRENT_USER_HOME_DIR=/home/$REMOTE_USER
		File=/etc/sudoers
		#allow root and vagrant user can switch to $REMOTE_USER without enter password
		if ! sudo grep -q "$REMOTE_USER ALL=(ALL)" "$File" ; then
		  # sudo echo $CURRENT_USER_NAME ALL = NOPASSWD: /bin/systemctl restart httpd.service, /bin/kill >> /etc/sudoers
		  # careful with that command
		  sudo echo "#config allow 'root' and 'vagrant' user dont need to enter password when switch to $REMOTE_USER user" | sudo tee -a /etc/sudoers > /dev/null
		  sudo echo "root ALL=($REMOTE_USER) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
		  sudo echo "vagrant ALL=($REMOTE_USER) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
		  
		  sudo echo "#allow $REMOTE_USER execute any comment without enter password" | sudo tee -a /etc/sudoers > /dev/null
	      sudo echo "$REMOTE_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
		fi
		unset File
			
		# Switch to the new user
		#echo "Switching to user '$REMOTE_USER'..."
		# su - $REMOTE_USER
		echo "Current user: $(whoami) $USER"
	fi
else 
	 echo "Please use the administrator user to setting."
fi

if [ ! -d $CURRENT_USER_HOME_DIR/.ssh ]; then
  echo "folder $CURRENT_USER_HOME_DIR/.ssh does not exist. Created it !!!"
  mkdir $CURRENT_USER_HOME_DIR/.ssh
  chmod 700 ~/.ssh
fi

if [ ! -e $CURRENT_USER_HOME_DIR/.ssh/config ]; then
	 echo "################################### file $CURRENT_USER_HOME_DIR/.ssh/config does not exist. Created it !!!"
	 sudo touch $CURRENT_USER_HOME_DIR/.ssh/config
	 sudo chown -R $CURRENT_USER:$CURRENT_USER $CURRENT_USER_HOME_DIR/.ssh/config 
	 sudo chmod 600 $CURRENT_USER_HOME_DIR/.ssh/config
fi

if [ ! -e $CURRENT_USER_HOME_DIR/.ssh/known_hosts ]; then
	 echo "################################### file $CURRENT_USER_HOME_DIR/.ssh/known_hosts does not exist. Created it !!!"
	 sudo touch $CURRENT_USER_HOME_DIR/.ssh/known_hosts
	 #sudo chgrp -R $CURRENT_USER $CURRENT_USER_HOME_DIR/.ssh/known_hosts
	 sudo chown -v $CURRENT_USER $CURRENT_USER_HOME_DIR/.ssh/known_hosts
fi

FOLDER_STORE_SSH_KEY="$CURRENT_USER_HOME_DIR/.ssh/remote-host-key"
# custom a random file name
FILE_NAME=$(echo $RANDOM | md5sum | head -c 20)


PATH_KEY=$FOLDER_STORE_SSH_KEY/$FILE_NAME
if [ ! -d $FOLDER_STORE_SSH_KEY ]; then
	 echo "################################### $FOLDER_STORE_SSH_KEY does not exist. Create it !!!"
	 sudo mkdir $FOLDER_STORE_SSH_KEY
fi

# we do not setup multi key for the same host name
if ! sudo grep -q "$REMOTE_HOST_NAME" $CURRENT_USER_HOME_DIR/.ssh/config; then 
	if [[ -n "$CUSTOM_KEY_PATH" && -n "$CUSTOM_KEY_NAME" ]]; then
		echo "exist custom ssh key path: $CUSTOM_KEY_PATH, key name: $CUSTOM_KEY_NAME"
		#### copy a file name
		cp "$CUSTOM_KEY_PATH/$CUSTOM_KEY_NAME" "$FOLDER_STORE_SSH_KEY/$FILE_NAME"
		cp "$CUSTOM_KEY_PATH/$CUSTOM_KEY_NAME.pub" "$FOLDER_STORE_SSH_KEY/$FILE_NAME.pub"
	else
		echo "Not exist custom sh key, create it."
		sudo ssh-keygen -f $PATH_KEY  -t ed25519 -b 4096 -N '' # -N '' mean not enter passphrase
	fi

	echo "Setup permission for ssh key."

	sudo chgrp -R $CURRENT_USER $FOLDER_STORE_SSH_KEY
	sudo chgrp -R $CURRENT_USER $PATH_KEY
	sudo chgrp -R $CURRENT_USER "$PATH_KEY.pub"
	sudo chown -R $CURRENT_USER:$CURRENT_USER $PATH_KEY
	sudo chown -R $CURRENT_USER:$CURRENT_USER "$PATH_KEY.pub"
	sudo chmod 600 $PATH_KEY
fi

########### add public key to remote server (authorized_keys) under $PATH_KEY folder 

if ! sudo grep -q "$REMOTE_HOST_NAME" $CURRENT_USER_HOME_DIR/.ssh/config; then 
	sudo echo "# ####zenkins server config to build host###" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "# try to ssh $REMOTE_USER@$REMOTE_HOST_NAME" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "Host $REMOTE_HOST_NAME" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     HostName $REMOTE_HOST_NAME" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     User $REMOTE_USER" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     PreferredAuthentications publickey" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     IdentitiesOnly yes" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     IdentityFile $PATH_KEY" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     UserKnownHostsFile $CURRENT_USER_HOME_DIR/.ssh/known_hosts" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	sudo echo "     Port 22" | sudo tee -a $CURRENT_USER_HOME_DIR/.ssh/config > /dev/null
	eval $(ssh-agent -s)
	sudo ssh-keyscan -H $REMOTE_HOST_NAME >> $CURRENT_USER_HOME_DIR/.ssh/known_hosts
    
	if [ $CURRENT_USER != root ] ; then
		# Set ownership of the home directory and subfolder to the new user
		chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER
	fi
		
	echo "################################### Random ssh keys was created at path: $PATH_KEY, please remember it."
	
	
	#add jenkins user to group
	groups
	#sudo usermod -a -G vagrant jenkins
	#sudo chmod g+rw $CURRENT_USER_HOME_DIR/.ssh/
	#sudo chmod g+rw $CURRENT_USER_HOME_DIR/.ssh/authorized_keys
	#sudo chmod g+r $CURRENT_USER_HOME_DIR/.ssh/config
	#sudo chmod g+rw $CURRENT_USER_HOME_DIR/.ssh/known_hosts
	
	#sudo chgrp -R $USER $FOLDER_STORE_SSH_KEY
	#sudo chgrp -R $USER $PATH_KEY
	#sudo chmod g+rw $FOLDER_STORE_SSH_KEY
	#sudo chmod g+rw $PATH_KEY
else
	echo "################################### Random ssh keys was existed at path: $PATH_KEY, please remember it."
fi

unset MY_NAME
unset REMOTE_HOST_NAME
unset REMOTE_USER
unset FOLDER_STORE_SSH_KEY
unset FILE_NAME
unset PATH_KEY
unset CUSTOM_KEY_PATH
unset CUSTOM_KEY_NAME
unset CURRENT_USER_HOME_DIR
unset CURRENT_USER