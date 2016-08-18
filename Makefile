TAG := master

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
