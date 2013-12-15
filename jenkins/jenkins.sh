function installJenkins() {
	wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | apt-key add -
	echo "deb http://pkg.jenkins-ci.org/debian binary/" >> /etc/apt/sources.list
	apt-get update
	apt-get install -y jenkins
}

