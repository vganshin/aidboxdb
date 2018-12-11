IMAGE_TAG  ?= $(shell git describe --tags 2> /dev/null || git rev-parse --short HEAD)

docker-run:
	docker run --rm -it aidbox/db:latest bash

docker-build:
	docker build -t aidbox/db:passive-latest -t aidbox/db:passive-${IMAGE_TAG} . --cache-from aidbox/db:latest
	docker build -f Dockerfile.active -t aidbox/db:${IMAGE_TAG} -t aidbox/db:latest .

docker-push:
	docker push aidbox/db:${IMAGE_TAG}
	docker push aidbox/db:latest
	docker push aidbox/db:passive-${IMAGE_TAG}
	docker push aidbox/db:passive-latest
