#!/bin/bash

# Change this in a live instance
PASSWORD="vagrant"
GF_VERSION="4.0"

GF_UNZIP_TARGET="/opt/"
ASADMIN="${GF_UNZIP_TARGET}glassfish4/bin/asadmin"
PASSWORD_FILE="/tmp/password.file"
GF_FILE_NAME="glassfish-$GF_VERSION.zip"
GF_WEB_LINK="http://download.java.net/glassfish/4.0/release/${GF_FILE_NAME}"
ZIP_LOCATION="/tmp/${GF_FILE_NAME}"

function bootstrapSystem() {
	apt-get -y -q install unzip openjdk-7-jdk 
}

function getGlassfish() {
	# See if file is provided
	if [ -f /vagrant/${GF_FILE_NAME} ]
	then
		# Copy the file
		cp /vagrant/${GF_FILE_NAME} ${ZIP_LOCATION}
	else
		# Download the file
		wget -cq ${GF_WEB_LINK} -O ${ZIP_LOCATION}	
	fi
}

function unpackGlassfish() {
	unzip $ZIP_LOCATION -d ${GF_UNZIP_TARGET}
}

function glassfishSetup() {
	# Changes default password to "vagrant" for admin
	echo "AS_ADMIN_PASSWORD=" > $PASSWORD_FILE
	echo "AS_ADMIN_NEWPASSWORD=$PASSWORD" >> $PASSWORD_FILE
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE start-domain
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE change-admin-password
	# Update the password file with fresh password
	echo "AS_ADMIN_PASSWORD=$PASSWORD" > $PASSWORD_FILE
}

function glassfishRestart() {
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE stop-domain
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE start-domain
}

function glassfishEnableSecureAdmin() {
	# Secure admin makes admin interface remotely accessible and encrypts all admin traffic
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE enable-secure-admin
	glassfishRestart
}

function removePasswordFile() {
	rm -f $PASSWORD_FILE
}

function installGlassfish() {
	if [ ! -d "${GF_UNZIP_TARGET}glassfish4" ]; then
		# If glassfish is not installed
		bootstrapSystem
		getGlassfish
		unpackGlassfish
		glassfishSetup
		glassfishEnableSecureAdmin
		removePasswordFile
	fi
}
