TAG := master

help:
	@echo 'Targets:'
	@echo '  * help     - prints this message'
	@echo '  * build    - compiles the self-contained bork install script'
	@echo '  * publish  - compiles and pushes the latest source code to github using the TAG provided'
	@echo '               ex. `make publish TAG=0.0.1` (TAG is set to `master` if not provided)'
	@echo '  * status   - runs bork status pants.sh'
	@echo '  * install  - runs bork satisfy pants.sh'

status:
	bork status pants.sh; echo "done (exitcode: $$?)"
.PHONY: status

install:
	bork satisfy pants.sh; echo "done (exitcode: $$?)"
.PHONY: install

build: install.sh
.PHONY: build

dist:
	@mkdir -p $@

install.sh: pants.sh | dist
	bork compile pants.sh > dist/install.sh
	@chmod +x dist/install.sh

PUBLISH_COMMAND := ${if ${patsubst master,,${TAG}},( git tag ${TAG}; git push origin ${TAG} ),git push -u origin master}
publish: install.sh
	@[ -z "$$(git status --porcelain)" ] && \
		( echo "$(PUBLISH_COMMAND)"; $(PUBLISH_COMMAND) || true ) || \
		echo "Your workspace has staged or untracked resources. Did you forget to commit?"
.PHONY: publish
