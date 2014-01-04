# **************************
# This is NOT fully complete
# **************************

REDMINE_VERSION="2.4.1"
REDMINE_NAME="redmine-$REDMINE_VERSION"
REDMINE_LOCATION="/home/vagrant/$REDMINE_NAME"
DB_CONFIG_PATH="database.yml"

function installPostgresqlForRedmine() {
	apt-get -y -q install postgresql postgresql-client
	su - postgres -c "echo \"CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD 'redmine' NOINHERIT VALID UNTIL 'infinity'; CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;\" | psql"
}

function setupPostgresConfig() {
	if [ -f "/vagrant/$DB_CONFIG_PATH" ]; then
		cp /vagrant/$DB_CONFIG_PATH $REDMINE_LOCATION/config/
	fi
}

function installRuby() {
	apt-get -y -q install make build-essential curl
	# RVM is needed as rubygems package is for version 1.8. puma can't use that
	curl -sSL https://get.rvm.io | bash -s stable
	source /home/vagrant/.rvm/scripts/rvm
	rvm use --install 2.0.0
	shift
	gem install bundler
}

function installDependencies() {
	apt-get -y -q install libpq-dev
	apt-get -y -q install libmagick++-dev
}

function setupRedmine() {
	wget http://www.redmine.org/releases/$REDMINE_NAME.tar.gz -O $REDMINE_LOCATION.tar.gz
	mkdir -p $REDMINE_LOCATION
	tar zxf $REDMINE_LOCATION.tar.gz -C /home/vagrant
}

function installPuma() {
	gem install puma
}

function bundlerInstall() {
	cd $REDMINE_LOCATION
	bundle install --without development test
}

function installLocales() {
	# Generate locales
	locale-gen en_GB en_GB.UTF-8 hu_HU hu_HU.UTF-8 en_US en_US.UTF-8
	dpkg-reconfigure locales

	# Set localesales
	export LANGUAGE=en_US.UTF-8
	export LANG=en_US.UTF-8
	export LC_ALL=en_US.UTF-8
}

function installRedmine() {
	# Generate locales if necessary! Needed for postgres
	#installLocales
	installPostgresqlForRedmine
	installRuby
	installDependencies
	setupRedmine
	setupPostgresConfig
	bundlerInstall
	installPuma
}
