PROJECT_DIR=$1
PROJECT_NAME=$2

function installPython {
	# Install python essentials
	apt-get install -y build-essential python python-dev python-setuptools python-pip
	wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python


	# Install pip
	if ! command -v pip; then
		easy_install -U pip
	fi
}

function installPostgresqlForTrac {
	PGSQL_VERSION=9.1
	if ! command -v psql; then
		apt-get install -y postgresql-$PGSQL_VERSION 
		apt-get install -y libpq-dev
		cp $PROJECT_DIR/provision/pg_hba.conf /etc/postgresql/$PGSQL_VERSION/main/
		/etc/init.d/postgresql reload
	fi

	# Set current locale for DB
	update-locale LANG=en_US.UTF8

	# Had to use template0, otherwise it was whining 'cause of mismatching UTF-8 <-> LATIN1 encodings
	createdb --encoding UTF8 --username postgres --locale en_US.UTF8 --template template0 trac
}

function installGenshi {
	# Needed for trac
	pip install Genshi
}

function installTracBasePackage {
	# psycopg2 is the postgres driver for python
	pip install trac psycopg2
}

function setupTracProject {
	WEB_USER=www-data
	# Create a new 'environment' for the project with appropriate DB settings
	trac-admin /var/$PROJECT_NAME initenv $PROJECT_NAME postgres://postgres@localhost/trac
	# Set ownership otherwise it will whine if conf/trac.ini is not writeable 
	chown -R $WEB_USER:$WEB_USER /var/$PROJECT_NAME
}

function installApacheBasePackages {
	# Install apache with wsgi mod
	apt-get install -y apache2 libapache2-mod-wsgi
}

APACHE2_CONF_FILE=/etc/apache2/httpd.conf
function setupLoginMechanismAndAdmin {
	REALM_NAME="trac"
	ADMIN_PASSWORD="Fmxtrac1"
	# Create admin
	# Originally the command should be: "htdigest -c /target/file.name realm username"
	# This is not cool as it will ask for the password 2 times but in the end it just generates 
	# username:realm:password where password is -> md5sum(username:realm:password)
	# All in all, it can be replroduced with this set of commands
	( echo -n "admin:$REALM_NAME:" && echo -n "admin:$REALM_NAME:$ADMIN_PASSWORD" | md5sum | awk '{print $1}' ) >> /var/$PROJECT_NAME/trac.htpasswd

	# Activate digest authentication
	a2enmod auth_digest
	
	# Add digest authentication to apache config file
	echo "<Location \"/login\">" >> $APACHE2_CONF_FILE
	echo -e "\tAuthType Digest" >> $APACHE2_CONF_FILE
	echo -e "\tAuthName \"$REALM_NAME\"" >> $APACHE2_CONF_FILE
	echo -e "\tAuthDigestDomain /" >> $APACHE2_CONF_FILE
	echo -e "\tAuthUserFile /var/$PROJECT_NAME/trac.htpasswd" >> $APACHE2_CONF_FILE
	echo -e "\tRequire valid-user" >> $APACHE2_CONF_FILE
	echo "</Location>" >> $APACHE2_CONF_FILE
	/etc/init.d/apache2 restart
}

function addTracToApache {
	TMP_TARGET_DIR=/tmp/tracproject
	# This is just to create the trac.wsgi folder
	trac-admin /var/$PROJECT_NAME deploy $TMP_TARGET_DIR
	cp $TMP_TARGET_DIR/cgi-bin/trac.wsgi /var/$PROJECT_NAME/

	URL_PATH=""

	# Add the 'site' to the httpd.conf
	echo "WSGIScriptAlias /$URL_PATH /var/$PROJECT_NAME/trac.wsgi" >> $APACHE2_CONF_FILE
	echo "" >> $APACHE2_CONF_FILE
	echo "<Directory /var/$PROJECT_NAME>" >> $APACHE2_CONF_FILE
	echo -e "\tWSGIApplicationGroup %{GLOBAL}" >> $APACHE2_CONF_FILE
	echo -e "\tOrder deny,allow" >> $APACHE2_CONF_FILE
	echo -e "\tAllow from all" >> $APACHE2_CONF_FILE
	echo "</Directory>" >> $APACHE2_CONF_FILE
	/etc/init.d/apache2 restart
}

function installTrac {
	installPython
	installPostgresqlForTrac
	installGenshi
	installTracBasePackage
	setupTracProject
	installApacheBasePackages
	addTracToApache
	setupLoginMechanismAndAdmin
}
