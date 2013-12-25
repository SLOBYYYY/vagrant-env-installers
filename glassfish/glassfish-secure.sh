#!/bin/bash
# This setup is more secure as it uses a dedicated user with limited rights to 
# install and manage glassfish

GF_UNZIP_TARGET="/opt/"
ASADMIN="${GF_UNZIP_TARGET}glassfish/bin/asadmin"
PASSWORD_FILE="/opt/glassfish/password.file"
ADMIN_PASSWORD="adminPassword"
MASTER_PASSWORD="masterPassword"
GLASSFISH_PATH="/opt/glassfish/glassfish"

setupUsers() {
	# Create a system level glasfish user and group. System user means that UID 
	# and GID are below 1000
	adduser --system --group --home /home/glassfish --shell /bin/bash glassfish
}

setupEnvVariables() { # Set java env variables
	BASHRC_FILE=/home/vagrant/.bashrc
	JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
	echo "export JAVA_HOME=$JAVA_HOME" >> $BASHRC_FILE
	echo "export JAVA_BINDIR=\"$JAVA_HOME/bin\"" >> $BASHRC_FILE
	echo "echo \$PATH | /bin/grep -q -v \"$JAVA_HOME/bin\"" >> $BASHRC_FILE
	echo "if [ $? -eq 0 ]; then export PATH=\"\$PATH:$JAVA_HOME/bin\"; fi" >> $BASHRC_FILE

	# Set glassfish env variables
	GLASSFISH_HOME=/opt/glassfish
	echo "export GLASSFISH_PARENT=$GLASSFISH_HOME" >> $BASHRC_FILE
	echo "export GLASSFISH_HOME=$GLASSFISH_HOME/glassfish/" >> $BASHRC_FILE
	echo "echo \$PATH | /bin/grep -q -v \"$GLASSFISH_HOME/glassfish/bin\"" >> $BASHRC_FILE
	echo "if [ $? -eq 0 ]; then export PATH=\"\$PATH:$GLASSFISH_HOME/glassfish/bin\"; fi" >> $BASHRC_FILE

	# Essential for running asadmin and keytool
	echo "export AS_JAVA=$JAVA_HOME" >> $BASHRC_FILE
}

bootstrapSystem() {
	sudo apt-get -y -q update
	sudo apt-get -y -q install unzip vim openjdk-7-jdk 
}

getGlassfish() {
	GF_FILE_NAME="glassfish-4.0.zip"
	GF_WEB_LINK="http://download.java.net/glassfish/4.0/release/${GF_FILE_NAME}"
	TEMP_LOCATION=/tmp/${GF_FILE_NAME}
	# See if file is provided
	if [ -f /vagrant/${GF_FILE_NAME} ]
	then
		# Copy the file
		cp /vagrant/${GF_FILE_NAME} ${TEMP_LOCATION}
	else
		# Download the file
		wget -cq ${GF_WEB_LINK} -O ${TEMP_LOCATION}	
	fi
}

unpackGlassfish() {
	unzip /tmp/glassfish-4.0.zip -d ${GF_UNZIP_TARGET}
	# Rename the zip
	mv $GF_UNZIP_TARGET/glassfish4 $GF_UNZIP_TARGET/glassfish
}

modifyFolderPermissions() {
	# Make the owner of the directory glassfish:glassfish
	chown -R glassfish:glassfish /opt/glassfish

	# Owner and group can read, write, execute files and autodeploy
	chmod -R ug+rwx /opt/glassfish/bin/
	chmod -R ug+rwx /opt/glassfish/glassfish/bin/
	chmod -R ug+rwx /opt/glassfish/glassfish/domains/domain1/autodeploy/

	# Make sure others can't read, write or execute or autodeploy in glassfish directories
	chmod -R o-rwx /opt/glassfish/bin/
	chmod -R o-rwx /opt/glassfish/glassfish/bin/
	chmod -R o-w /opt/glassfish/glassfish/domains/domain1/autodeploy/
}

changePasswords() {
	su - glassfish -c "tar cf passwords.orig.tar $GLASSFISH_PATH/domains/domain1/config/domain-passwords $GLASSFISH_PATH/domains/domain1/config/keystore.jks $GLASSFISH_PATH/domains/domain1/config/cacerts.jks"

	# Change default master password
	su - glassfish -c "echo \"AS_ADMIN_MASTERPASSWORD=changeit\" > $PASSWORD_FILE"
	su - glassfish -c "echo \"AS_ADMIN_NEWMASTERPASSWORD=$MASTER_PASSWORD\" >> $PASSWORD_FILE"
	su - glassfish -c "$ASADMIN --passwordfile $PASSWORD_FILE change-master-password --savemasterpassword=true domain1"

	su - glassfish -c "echo \"AS_ADMIN_MASTERPASSWORD=$MASTER_PASSWORD\" > $PASSWORD_FILE"
	su - glassfish -c "echo \"AS_ADMIN_PASSWORD=\" >> $PASSWORD_FILE"
	su - glassfish -c "echo \"AS_ADMIN_NEWPASSWORD=$ADMIN_PASSWORD\" >> $PASSWORD_FILE"
	su - glassfish -c "$ASADMIN --passwordfile $PASSWORD_FILE start-domain"
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE change-admin-password"

	# Update the password file with fresh password
	su - glassfish -c "echo \"AS_ADMIN_PASSWORD=$ADMIN_PASSWORD\" > $PASSWORD_FILE"
	su - glassfish -c "echo \"AS_ADMIN_MASTERPASSWORD=$MASTER_PASSWORD\" >> $PASSWORD_FILE"
}

generatePassFile() {
	# Login, thus create a file ~/.gfclient/pass storing the login information
	# NOT WORKING --> It does not accept piped answers for interactive questions
	su - glassfish -c "echo -e \"\nadmin$ADMIN_PASSWORD\n\" | $ASADMIN login"
}

updateCertificates() {
	SERVER_DOMAIN_NAME="vps.dev"
	ORGANIZATION_UNIT="SomeOrganizationUnit"
	ORGANIZATION="SomeOrganization"
	LOCATION="SomeLocation"
	STATE="SomeState"
	COUNTRY="HU"
	# The certificates (namely "s1as" and "glassfish-instance") are default, 
	# therefore known by everyone. It's unsecure so we change them
	KEYSTORE_PATH=$GLASSFISH_PATH/domains/domain1/config/keystore.jks

	# Delete old instances of the two certificates
	su - glassfish -c "keytool -delete -alias s1as -keystore $KEYSTORE_PATH -storepass $MASTER_PASSWORD"
	su - glassfish -c "keytool -delete -alias glassfish-instance -keystore $KEYSTORE_PATH -storepass $MASTER_PASSWORD"
	DNAME="CN=$SERVER_DOMAIN_NAME,OU=$ORGANIZATION_UNIT,O=$ORGANIZATION,L=$LOCATION,S=$STATE,C=$COUNTRY"

	# Recreate the certificates
	su - glassfish -c "keytool -genkeypair -alias s1as -dname \"$DNAME\" -keyalg RSA -keysize 2048 -validity 3650 -keystore $KEYSTORE_PATH -keypass $MASTER_PASSWORD -storepass $MASTER_PASSWORD"
	su - glassfish -c "keytool -genkeypair -alias glassfish-instance -dname \"$DNAME\" -keyalg RSA -keysize 2048 -validity 3650 -keystore $KEYSTORE_PATH -keypass $MASTER_PASSWORD -storepass $MASTER_PASSWORD"

	# Export 2 new certificates from keystore
	su - glassfish -c "keytool -exportcert -alias s1as -file $GLASSFISH_PATH/s1as.cert -keystore $KEYSTORE_PATH -storepass $MASTER_PASSWORD"
	su - glassfish -c "keytool -exportcert -alias glassfish-instance -file $GLASSFISH_PATH/glassfish-instance.cert -keystore $KEYSTORE_PATH -storepass $MASTER_PASSWORD"

	# Update cacerts.jks with the exported certificates
	CACERT_PATH=$GLASSFISH_PATH/domains/domain1/config/cacerts.jks
	su - glassfish -c "keytool -delete -alias s1as -keystore $CACERT_PATH -storepass $MASTER_PASSWORD"
	su - glassfish -c "keytool -delete -alias glassfish-instance -keystore $CACERT_PATH -storepass $MASTER_PASSWORD"
	su - glassfish -c "echo -e \"yes\n\" | keytool -importcert -alias s1as -file $GLASSFISH_PATH/s1as.cert -keystore $CACERT_PATH -storepass $MASTER_PASSWORD"
	su - glassfish -c "echo -e \"yes\n\" | keytool -importcert -alias glassfish-instance -file $GLASSFISH_PATH/glassfish-instance.cert -keystore $CACERT_PATH -storepass $MASTER_PASSWORD"

	# Cleanup
	rm $GLASSFISH_PATH/s1as.cert $GLASSFISH_PATH/glassfish-instance.cert
}

enableRemoteAccess() {
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE set server-config.network-config.protocols.protocol.admin-listener.security-enabled=true"
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE enable-secure-admin"
}

restartGlassfish() {
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE stop-domain
	$ASADMIN --user admin --passwordfile $PASSWORD_FILE start-domain
}

obfuscateHTMLHeaders() {
	# Removes HTML headers like "X-Powered-by" signaling the client that it's a glassfish server
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE create-jvm-options -Dproduct.name="
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE set server.network-config.protocols.protocol.http-listener-1.http.xpowered-by=false"
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE set server.network-config.protocols.protocol.http-listener-2.http.xpowered-by=false"
	su - glassfish -c "$ASADMIN --user admin --passwordfile $PASSWORD_FILE set server.network-config.protocols.protocol.admin-listener.http.xpowered-by=false"
}

setupUsers
bootstrapSystem
setupEnvVariables
getGlassfish
unpackGlassfish
modifyFolderPermissions
changePasswords
#generatePassFile
updateCertificates
enableRemoteAccess
obfuscateHTMLHeaders
