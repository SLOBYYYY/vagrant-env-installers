function installSMTP() {
	apt-get install -y exim4-daemon-light mailutils
	cp exim4.conf /etc/exim4/update-exim4.conf.conf
	update-exim4.conf
}
