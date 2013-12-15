function installSVNBasePackages() {
	apt-get install -y subversion
	# Install subversion WebDAV apache module
	apt-get install -y libapache2-svn
	# Restart apache to activate new module
	service apache2 restart
}

function createRepository() {
	mkdir -p /var/svnrepos/
	svnadmin create --fs-type fsfs /var/svnrepos/farmmixerp
	# Create group for svn users
	groupadd subversion
	addgroup root subversion
	chown -R www-data:subversion /var/svnrepos/*
	chmod -R 770 /var/svnrepos/*
}

function addSSHConnection() {
	if [ ! -d ~/.ssh/ ] 
	then
		printf "\n\n\n" | ssh-keygen -t rsa -b 2048
	fi
	cat id_rsa.pub >> ~/.ssh/authorized_keys
}

function installSVN() {
	installSVNBasePackages
	createRepository
	addSSHConnection
}
