# !!!!!!!!!!!!!!!!!!!!
# This is NOT complete
# !!!!!!!!!!!!!!!!!!!!
function installPostgresqlForRedmine() {
	apt-get install -y postgresql postgresql-client
	su - postgres -c "echo \"CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD 'redmine' NOINHERIT VALID UNTIL 'infinity'; CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;\" | psql"
}

function installRuby() {
	apt-get install -y make build-essential curl
	# RVM is needed as rubygems package is for version 1.8. puma can't use that
	curl -sSL https://get.rvm.io | bash -s stable
	source /home/vagrant/.rvm/scripts/rvm
	rvm use --install 2.0.0
	shift
	gem install bundler
}

function installPuma() {
	gem install puma
}

function installRedmine() {
	wget http://www.redmine.org/releases/redmine-2.4.1.tar.gz -O /home/vagrant/redmine-2.4.1.tar.gz
	cd /home/vagrant/
	tar zxf redmine-2.4.1.tar.gz
	cd redmine-2.4.1
	cp /home/vagrant/vps/provision/database.yml ./config/
	apt-get install -y libpq-dev
	apt-get install -y libmagick++-dev
	bundle install --without development test
}
