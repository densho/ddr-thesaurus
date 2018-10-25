PROJECT=ddr
APP=ddrthesaurus
USER=ddr
SHELL = /bin/bash

APP_VERSION := $(shell cat VERSION)
GIT_SOURCE_URL=https://github.com/densho/ddr-thesaurus

# Release name e.g. jessie
DEBIAN_CODENAME := $(shell lsb_release -sc)
# Release numbers e.g. 8.10
DEBIAN_RELEASE := $(shell lsb_release -sr)
# Sortable major version tag e.g. deb8
DEBIAN_RELEASE_TAG = deb$(shell lsb_release -sr | cut -c1)

# current branch name minus dashes or underscores
PACKAGE_BRANCH := $(shell git rev-parse --abbrev-ref HEAD | tr -d _ | tr -d -)
# current commit hash
PACKAGE_COMMIT := $(shell git log -1 --pretty="%h")
# current commit date minus dashes
PACKAGE_TIMESTAMP := $(shell git log -1 --pretty="%ad" --date=short | tr -d -)

PACKAGE_SERVER=ddr.densho.org/static/ddrthesaurus

CWD := $(shell pwd)
INSTALL_THESAURUS=$(CWD)
INSTALL_STATIC=$(INSTALL_THESAURUS)/static

VIRTUALENV=$(INSTALL_THESAURUS)/venv
SETTINGS=$(INSTALL_THESAURUS)/ddrthesaurus/ddrthesaurus/settings.py

CONF_BASE=/etc/ddr
CONF_PRODUCTION=$(CONF_BASE)/ddrthesaurus.cfg
CONF_LOCAL=$(CONF_BASE)/ddrthesaurus-local.cfg

SQLITE_BASE=/var/lib/ddr
LOG_BASE=/var/log/ddr

MEDIA_BASE=/var/www/ddrthesarus
MEDIA_ROOT=$(MEDIA_BASE)/media
STATIC_ROOT=$(MEDIA_BASE)/static

BOOTSTRAP=bootstrap-3.1.1-dist

SUPERVISOR_GUNICORN_CONF=/etc/supervisor/conf.d/ddrthesaurus.conf
SUPERVISOR_CONF=/etc/supervisor/supervisord.conf
NGINX_CONF=/etc/nginx/sites-available/ddrthesaurus.conf
NGINX_CONF_LINK=/etc/nginx/sites-enabled/ddrthesaurus.conf

DEB_BRANCH := $(shell git rev-parse --abbrev-ref HEAD | tr -d _ | tr -d -)
DEB_ARCH=amd64
DEB_NAME_STRETCH=$(APP)-$(DEB_BRANCH)
# Application version, separator (~), Debian release tag e.g. deb8
# Release tag used because sortable and follows Debian project usage.
DEB_VERSION_STRETCH=$(APP_VERSION)~deb9
DEB_FILE_STRETCH=$(DEB_NAME_STRETCH)_$(DEB_VERSION_STRETCH)_$(DEB_ARCH).deb
DEB_VENDOR=Densho.org
DEB_MAINTAINER=<geoffrey.jost@densho.org>
DEB_DESCRIPTION=Densho Digital Repository editor
DEB_BASE=opt/ddr-thesaurus


.PHONY: help


help:
	@echo "--------------------------------------------------------------------------------"
	@echo "ddr-thesaurus make commands"
	@echo ""
	@echo "Most commands have subcommands (ex: install-ddr-cmdln, restart-supervisor)"
	@echo ""
	@echo "get     - Clones ddr-thesaurus, ddr-cmdln, ddr-defs, wgets static files & ES pkg."
	@echo "install - Performs complete install. See also: make howto-install"
	@echo "test    - Run unit tests"
	@echo "reload  - Reloads supervisord and nginx configs"
	@echo "restart - Restarts all daemons"
	@echo "status  - Server status"
	@echo ""
	@echo "migrate        - Init/update Django app's database tables."
	@echo ""
	@echo "deb       - Makes a DEB package install file."
	@echo "remove    - Removes Debian packages for dependencies."
	@echo "uninstall - Deletes 'compiled' Python files. Leaves build dirs and configs."
	@echo "clean     - Deletes files created while building app, leaves configs."
	@echo ""


get: get-app get-ddr-thesaurus get-static

install: install-prep install-daemons install-app install-static install-configs

test: test-app

uninstall: uninstall-app uninstall-configs

clean: clean-app


install-prep: ddr-user install-core git-config install-misc-tools

ddr-user:
	-addgroup --gid=1001 ddr
	-adduser --uid=1001 --gid=1001 --home=/home/ddr --shell=/bin/bash ddr
	-addgroup ddr plugdev
	-addgroup ddr vboxsf
	printf "\n\n# ddrthesaurus: Activate virtualnv on login\nsource $(VIRTUALENV)/bin/activate\n" >> /home/ddr/.bashrc; \

install-core:
	apt-get --assume-yes install bzip2 curl gdebi-core git-core logrotate ntp p7zip-full wget

git-config:
	git config --global alias.st status
	git config --global alias.co checkout
	git config --global alias.br branch
	git config --global alias.ci commit

install-misc-tools:
	@echo ""
	@echo "Installing miscellaneous tools -----------------------------------------"
	apt-get --assume-yes install ack-grep byobu elinks htop mg multitail


install-daemons: install-mariadb install-nginx install-redis

remove-daemons: remove-mariadb remove-nginx remove-redis


install-mariadb:
	@echo ""
	@echo "Nginx ------------------------------------------------------------------"
	apt-get --assume-yes install mariadb-server mariadb-client

remove-mariadb:
	apt-get --assume-yes remove mariadb-server mariadb-client

install-nginx:
	@echo ""
	@echo "Nginx ------------------------------------------------------------------"
	apt-get --assume-yes remove apache2
	apt-get --assume-yes install nginx

remove-nginx:
	apt-get --assume-yes remove nginx

install-redis:
	@echo ""
	@echo "Redis ------------------------------------------------------------------"
	apt-get --assume-yes install redis-server

remove-redis:
	apt-get --assume-yes remove redis-server


install-virtualenv:
	@echo ""
	@echo "install-virtualenv -----------------------------------------------------"
	apt-get --assume-yes install python3-pip python3-virtualenv python3-dev
	test -d $(VIRTUALENV) || virtualenv --python=/usr/bin/python3 --distribute --setuptools $(VIRTUALENV)
	source $(VIRTUALENV)/bin/activate; \
	pip3 install -U bpython appdirs blessings curtsies greenlet packaging pygments pyparsing setuptools wcwidth
#	virtualenv --relocatable $(VIRTUALENV)  # Make venv relocatable


mkdirs: mkdir-ddr-cmdln mkdir-ddr-thesaurus


get-app: get-ddr-thesaurus get-ddr-manual

install-app: install-virtualenv install-ddr-thesaurus install-configs install-daemon-configs

test-app: test-ddr-thesaurus

uninstall-app: uninstall-ddr-thesaurus uninstall-configs uninstall-daemon-configs

clean-app: clean-ddr-thesaurus clean-ddr-manual


get-ddr-thesaurus:
	@echo ""
	@echo "get-ddr-thesaurus ----------------------------------------------------------"
	git status | grep "On branch"
	git pull

install-ddr-thesaurus: install-virtualenv mkdir-ddr-thesaurus
	@echo ""
	@echo "install-ddr-thesaurus ------------------------------------------------------"
	git status | grep "On branch"
	source $(VIRTUALENV)/bin/activate; \
	pip3 install -U -r $(INSTALL_THESAURUS)/requirements.txt

mkdir-ddr-thesaurus:
	@echo ""
	@echo "mkdir-ddr-thesaurus --------------------------------------------------------"
# logs dir
	-mkdir $(LOG_BASE)
	chown -R ddr.root $(LOG_BASE)
	chmod -R 755 $(LOG_BASE)
# sqlite db dir
	-mkdir $(SQLITE_BASE)
	chown -R ddr.root $(SQLITE_BASE)
	chmod -R 755 $(SQLITE_BASE)
# media dir
	-mkdir -p $(MEDIA_ROOT)
	chown -R ddr.root $(MEDIA_ROOT)
	chmod -R 755 $(MEDIA_ROOT)
# static dir
	-mkdir -p $(STATIC_ROOT)
	chown -R ddr.root $(STATIC_ROOT)
	chmod -R 755 $(STATIC_ROOT)

test-ddr-thesaurus:
	@echo ""
	@echo "test-ddr-thesaurus ---------------------------------------------------------"
	source $(VIRTUALENV)/bin/activate; \
	cd $(INSTALL_THESAURUS)/ddr && tox

uninstall-ddr-thesaurus: install-virtualenv
	@echo ""
	@echo "uninstall-ddr-thesaurus ----------------------------------------------------"
	source $(VIRTUALENV)/bin/activate; \
	pip3 uninstall -y -r requirements.txt

clean-ddr-thesaurus:
	-rm -Rf $(VIRTUALENV)
	-rm -Rf *.deb


migrate:
	source $(VIRTUALENV)/bin/activate; \
	cd $(INSTALL_THESAURUS)/ddrthesaurus && $(INSTALL_THESAURUS)/ddrthesaurus/manage.py migrate --noinput
	chown -R ddr.root $(SQLITE_BASE)
	chmod -R 750 $(SQLITE_BASE)
	chown -R ddr.root $(LOG_BASE)
	chmod -R 755 $(LOG_BASE)


get-static: get-bootstrap

get-bootstrap:
	@echo ""
	@echo "Bootstrap --------------------------------------------------------------"
	mkdir -p $(INSTALL_STATIC)/
	wget -nc -P $(INSTALL_STATIC) http://$(PACKAGE_SERVER)/$(BOOTSTRAP).zip
	7z x -y -o$(INSTALL_STATIC) $(INSTALL_STATIC)/$(BOOTSTRAP).zip
	-rm $(INSTALL_STATIC)/$(BOOTSTRAP).zip

install-static:
	@echo ""
	@echo "install-static ---------------------------------------------------------"
	mkdir -p $(STATIC_ROOT)/
	cp -R $(INSTALL_STATIC)/* $(STATIC_ROOT)/
	chown -R root.root $(STATIC_ROOT)/
	-ln -s $(STATIC_ROOT)/$(BOOTSTRAP) $(STATIC_ROOT)/bootstrap

clean-static:
	-rm -Rf $(STATIC_ROOT)/
	-rm -Rf $(INSTALL_STATIC)/*


install-configs:
	@echo ""
	@echo "configuring ddr-thesaurus --------------------------------------------------"
# base settings file
	-mkdir /etc/ddr
	cp $(INSTALL_THESAURUS)/conf/ddrthesaurus.cfg $(CONF_PRODUCTION)
	chown root.root $(CONF_PRODUCTION)
	chmod 644 $(CONF_PRODUCTION)
	touch $(CONF_LOCAL)
	chown ddr.root $(CONF_LOCAL)
	chmod 640 $(CONF_LOCAL)
# web app settings
	cp $(INSTALL_THESAURUS)/conf/settings.py $(SETTINGS)
	chown root.root $(SETTINGS)
	chmod 644 $(SETTINGS)

uninstall-configs:
	-rm $(SETTINGS)
	-rm $(CONF_PRODUCTION)


install-daemon-configs:
	@echo ""
	@echo "install-daemon-configs -------------------------------------------------"
# nginx settings
	cp $(INSTALL_THESAURUS)/conf/nginx.conf $(NGINX_CONF)
	chown root.root $(NGINX_CONF)
	chmod 644 $(NGINX_CONF)
	-ln -s $(NGINX_CONF) $(NGINX_CONF_LINK)
	-rm /etc/nginx/sites-enabled/default
# supervisord
	cp $(INSTALL_THESAURUS)/conf/celeryd.conf $(SUPERVISOR_CELERY_CONF)
	cp $(INSTALL_THESAURUS)/conf/supervisor.conf $(SUPERVISOR_GUNICORN_CONF)
	cp $(INSTALL_THESAURUS)/conf/supervisord.conf $(SUPERVISOR_CONF)
	chown root.root $(SUPERVISOR_CELERY_CONF)
	chown root.root $(SUPERVISOR_GUNICORN_CONF)
	chown root.root $(SUPERVISOR_CONF)
	chmod 644 $(SUPERVISOR_CELERY_CONF)
	chmod 644 $(SUPERVISOR_GUNICORN_CONF)
	chmod 644 $(SUPERVISOR_CONF)

uninstall-daemon-configs:
	-rm $(NGINX_CONF)
	-rm $(NGINX_CONF_LINK)
	-rm $(SUPERVISOR_CELERY_CONF)
	-rm $(SUPERVISOR_CONF)


reload: reload-nginx reload-supervisor

reload-nginx:
	sudo service nginx reload

reload-supervisor:
	supervisorctl reload

reload-app: reload-supervisor


stop: stop-redis stop-nginx stop-supervisor

stop-redis:
	-service redis-server stop

stop-nginx:
	-service nginx stop

stop-supervisor:
	-service supervisor stop

stop-app: stop-supervisor


restart: restart-supervisor restart-redis restart-nginx

restart-redis:
	-service redis-server restart

restart-nginx:
	-service nginx restart

restart-supervisor:
	-service supervisor stop
	-service supervisor start

restart-app: restart-supervisor


# just Redis and Supervisor
restart-minimal: restart-redis stop-nginx restart-supervisor


status:
	@echo "------------------------------------------------------------------------"
	-systemctl status redis-server
	@echo " - - - - -"
	-systemctl status nginx
	@echo " - - - - -"
	-systemctl status supervisor
	-supervisorctl status
	@echo " - - - - -"
	-uptime
	@echo ""


# http://fpm.readthedocs.io/en/latest/
install-fpm:
	@echo "install-fpm ------------------------------------------------------------"
	apt-get install ruby ruby-dev rubygems build-essential
	gem install --no-ri --no-rdoc fpm

# https://stackoverflow.com/questions/32094205/set-a-custom-install-directory-when-making-a-deb-package-with-fpm
# https://brejoc.com/tag/fpm/
deb: deb-stretch

# deb-jessie and deb-stretch are identical EXCEPT:
# jessie: --depends openjdk-7-jre
# stretch: --depends openjdk-7-jre
deb-stretch:
	@echo ""
	@echo "FPM packaging (stretch) ------------------------------------------------"
	-rm -Rf $(DEB_FILE_STRETCH)
# Copy .git/ dir from master worktree
	python bin/deb-prep-post.py before
# Make venv relocatable
	virtualenv --relocatable $(VIRTUALENV)
# Make package
	fpm   \
	--verbose   \
	--input-type dir   \
	--output-type deb   \
	--name $(DEB_NAME_STRETCH)   \
	--version $(DEB_VERSION_STRETCH)   \
	--package $(DEB_FILE_STRETCH)   \
	--url "$(GIT_SOURCE_URL)"   \
	--vendor "$(DEB_VENDOR)"   \
	--maintainer "$(DEB_MAINTAINER)"   \
	--description "$(DEB_DESCRIPTION)"   \
	--depends "nginx-light"   \
	--depends "fcgiwrap"   \
	--depends "gdebi-core"   \
	--depends "python3-dev"   \
	--depends "python3-pip"   \
	--depends "python3-virtualenv"   \
	--depends "redis-server"   \
	--depends "supervisor"   \
	--chdir $(INSTALL_THESAURUS)   \
	conf/ddrthesaurus.cfg=etc/ddr/ddrthesaurus.cfg   \
	conf/supervisor.conf=etc/supervisor/conf.d/ddrthesaurus.conf   \
	conf/nginx.conf=etc/nginx/sites-available/ddrthesaurus.conf   \
	conf/logrotate=etc/logrotate.d/ddr   \
	conf/README-logs=$(LOG_BASE)/README  \
	conf/README-media=$(MEDIA_ROOT)/README  \
	conf/README-static=$(STATIC_ROOT)/README  \
	static=var/www/ddrthesaurus   \
	bin=$(DEB_BASE)   \
	conf=$(DEB_BASE)   \
	COPYRIGHT=$(DEB_BASE)   \
	ddrthesaurus=$(DEB_BASE)   \
	.git=$(DEB_BASE)   \
	.gitignore=$(DEB_BASE)   \
	INSTALL.rst=$(DEB_BASE)   \
	LICENSE=$(DEB_BASE)   \
	Makefile=$(DEB_BASE)   \
	README.rst=$(DEB_BASE)   \
	requirements.txt=$(DEB_BASE)   \
	static=$(DEB_BASE)   \
	venv=$(DEB_BASE)   \
	VERSION=$(DEB_BASE)
# Put worktree pointer file back in place
	python bin/deb-prep-post.py after
