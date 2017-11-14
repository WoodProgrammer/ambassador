all: dev

VERSION=$(shell python scripts/versioner.py --bump --magic-pre)

.ALWAYS:

dev: deps-check version-check reg-check versions docker-images yaml-files

travis-images: deps-check version-check reg-check versions docker-images

travis-website: version-check website

deps-check:
	@python -c "import sys; sys.exit(0 if sys.version_info > (3,4) else 1)" || { \
		echo "Python 3.4 or higher is required" >&2; \
		exit 1 ;\
	}
	@which pytest >/dev/null 2>&1 || { \
		echo "Could not find pytest -- is it installed?" >&2 ;\
		echo "(if not, pip install -r dev-requirements may do the trick)" >&2 ;\
		exit 1 ;\
	}
	@python -c 'import semantic_version, git' >/dev/null 2>&1 || { \
		echo "Could not import semantic_version or git -- are they installed?" >&2 ;\
		echo "(if not, pip install -r dev-requirements may do the trick)" >&2 ;\
		exit 1 ;\
	}
	@which aws >/dev/null 2>&1 || { \
		echo "Could not find aws -- is it installed?" >&2 ;\
		echo "(if not, check out https://docs.npmjs.com/getting-started/installing-node)" >&2 ;\
		exit 1 ;\
	}

version-check:
	@if [ -z "$(VERSION)" ]; then \
		echo "Nothing needs to be built" >&2 ;\
		exit 1 ;\
	fi

reg-check:
	@if [ -z "$$DOCKER_REGISTRY" ]; then \
	    echo "DOCKER_REGISTRY must be set" >&2 ;\
	    exit 1 ;\
	fi

versions:
	@echo "Building $(VERSION)"
	sed -e "s/{{VERSION}}/$(VERSION)/g" < VERSION-template.py > ambassador/VERSION.py

artifacts: docker-images website

tag:
	git tag -a v$(VERSION) -m "v$(VERSION)"

yaml-files:
	VERSION=$(VERSION) sh scripts/build-yaml.sh
	VERSION=$(VERSION) python scripts/template.py \
		< annotations/ambassador-deployment-template.yaml \
		> annotations/ambassador-deployment.yaml

ambassador-test:
	pytest

docker-images: ambassador-image statsd-image

ambassador-image: ambassador-test .ALWAYS
	scripts/docker_build_maybe_push ambassador $(VERSION) ambassador

statsd-image: .ALWAYS
	scripts/docker_build_maybe_push statsd $(VERSION) statsd

website: yaml-files
	VERSION=$(VERSION) docs/build-website.sh

clean:
	rm -rf docs/yaml docs/_book docs/_site docs/node_modules
	rm -rf app.json
	rm -rf ambassador/__pycache__
	rm -rf .cache ambassador/.cache
	find ambassador/tests \( -name '*.out' -o -name 'envoy.json' \) -print0 | xargs -0 rm -f
	rm -rf annotations/ambassador-deployment.yaml
	find annotations \( -name 'check-*.json' -o -name 'envoy.json' \) -print0 | xargs -0 rm -f

