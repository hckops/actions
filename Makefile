require-%:
	@ if [ "$(shell command -v ${*} 2> /dev/null)" = "" ]; then \
		echo "[$*] not found"; \
		exit 1; \
	fi

check-param-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Missing parameter: [$*]"; \
		exit 1; \
	fi

##############################

DOCKER_USERNAME := hckops

##############################

.PHONY: docker-build
docker-build: require-docker
	./scripts/docker_apply.sh "build" "base"
	./scripts/docker_apply.sh "build" "do"
	./scripts/docker_apply.sh "build" "aws"

# use "@" prefix to don't print command
.PHONY: docker-login
docker-login: require-docker check-param-token
	@echo ${token} | docker login -u $(DOCKER_USERNAME) --password-stdin

.PHONY: docker-publish
docker-publish: require-docker check-param-version docker-login docker-build
	./scripts/docker_apply.sh "publish" "base" ${version}
	./scripts/docker_apply.sh "publish" "do" ${version}
	./scripts/docker_apply.sh "publish" "aws" ${version}

.PHONY: docker-clean
docker-clean: require-docker
	./scripts/docker_apply.sh "clean" "*"

##############################

.PHONY: bootstrap
bootstrap: require-helm require-kubectl
	./scripts/local.sh "bootstrap" ${kube}

.PHONY: discord-create
discord-create: require-curl check-param-webhook check-param-message
	./discord-action/entrypoint.sh "create-message" ${webhook} ${message}

##############################

.PHONY: update-version
update-version: check-param-old check-param-new
	grep -l -r ${old} */Dockerfile | xargs sed -i 's/${old}/${new}/'
