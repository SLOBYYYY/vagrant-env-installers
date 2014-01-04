PROJECT_NAME=$1

function installGitBasePackages() {
	apt-get -y -q install git
}

function setupSecureUser() {
	# Create a git user that has the only privilege to access the repository
	GIT_USER_HOME_DIR="/home/git"
	adduser git
	# TODO: Set password for user!!
	GIT_USER_SSH_DIR="$GIT_USER_HOME_DIR/.ssh"
	su - git -c "mkdir -p $GIT_USER_SSH_DIR"
	su - git -c "touch $GIT_USER_SSH_DIR/authorized_keys"
}

function createRepository() {
	REPOSITORY_BASE_LOCATION="/opt/repositories/"
	PROJECT_REPOSITORY="${REPOSITORY_BASE_LOCATION}${PROJECT_NAME}.git"

	mkdir -p $PROJECT_REPOSITORY
	chown git $PROJECT_REPOSITORY
	chgrp git $PROJECT_REPOSITORY
	su - git -c "cd $PROJECT_REPOSITORY"
	su - git -c "git --bare init"
	chmod -R o-rwx $PROJECT_REPOSITORY
}

function setRemoteAuthentication() {
	# Put the public keys in the authorized_keys file like this:
	# cat id_rsa.pub >> /home/git/.ssh/authorized_keys
}

function installGit() {
	installGitBasePackages
	setupSecureUser
	createRepository
}
