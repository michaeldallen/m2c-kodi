LOG   = 2>&1 | tee -a log.$(shell date +%Y.%m.%d_%H.%M.%S).$@
DATE  = date | sed -n '/\(.*\)/ { h ; 's/./-/g' p ; x ; p ; x ; p }'

SHELL := /bin/bash

ARCH := $(shell dpkg --print-architecture)

# TODO: experimenting with overlay (vs. overlay2) for jenkins-in-docker-in-docker debugging - should move off overlay
# https://github.com/docker/for-linux/issues/711

.PHONY: make.vars make.targets make.clean make.default

make.default : make.vars make.targets

make.vars :
	@echo "available variables"
	@$(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null \
	| awk '/^# makefile/,/^[^#]/ { if ($$1 !~ "^[#.]") {print $$$$1} }' \
	| sed -e 's/ := / !:= /' -e 's/ = / ! = /' \
	| column -t -s'!' \
	| sed 's/  \([:=]\)/\1/' \
	| sed 's/^/    /' \
	| sort

make.targets :
	@echo "available Make targets:"
	@$(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null \
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
	| egrep -v '^make.default$$' \
	| sed 's/^/    make    /' \
	| sort \
	| sed 's/make    maven.release$$/make -n maven.release/'


make.clean : 
	@find * -name '*~' -print -delete
	@rm -fv log.*

make.clean.all : 
	@$(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null \
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
	| egrep '\.clean$$' \
	| sort \
	| xargs --max-lines=1 $(MAKE) 

IAM := m2c-kodi-${ARCH}
DOCKER_ROOT := kodi

docker.build :
	docker build --tag ${IAM} ${DOCKER_ROOT}


docker.run.bash : docker.socket.usable
	docker \
		run \
		-it \
		--rm \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--hostname="${DOCKER_ROOT}:`hostname --fqdn`" \
		--name ${IAM} \
		${IAM} \
		/bin/bash

docker.socket.usable :
	@echo checking docker socket usability
	@{ [ `awk -F: '$$1 == "docker" {print $$3}' /etc/group` -eq 999 ] && echo "ok: docker GID is 999" ; } || \
	 { [ `stat --print=%a /var/run/docker.sock | cut -c3` -ge 6 ] && echo "ok: docker socket is world read/writeable" ; } || \
	 { echo "docker socket unusable" ; /bin/false ; }



${DOCKER_ROOT}.run.local : docker.socket.usable
	docker \
		run \
		--rm \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--hostname="${DOCKER_ROOT}:`hostname --fqdn`" \
		--name ${IAM} \
		${IAM} \
		 #

${DOCKER_ROOT}.jenkins.run.local.daemon : docker.socket.usable
	docker \
		run \
		--detach \
		--rm \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--hostname="${DOCKER_ROOT}:`hostname --fqdn`" \
		--name ${IAM} \
		${IAM} \
		 #

${DOCKER_ROOT}.logs :
	docker \
		logs -f \
		${IAM} \
		 #


${DOCKER_ROOT}.stop :
	docker \
		stop \
		${IAM} \
		 #


#EOF
