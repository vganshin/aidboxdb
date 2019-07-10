# IMAGE_TAG  ?= $(shell git describe --tags 2> /dev/null || git rev-parse --short HEAD)
IMAGE_TAG  = $(shell cat VERSION)

.PHONY: build

docker-run:
	docker run --rm -it aidbox/db:latest bash

build:
	docker build -t aidbox/db:passive-latest -t aidbox/db:passive-${IMAGE_TAG} .
	docker build -f Dockerfile.active -t aidbox/db:${IMAGE_TAG} -t aidbox/db:latest .

publish:
	docker push aidbox/db:${IMAGE_TAG}
	# docker push aidbox/db:latest
	docker push aidbox/db:passive-${IMAGE_TAG}
	# docker push aidbox/db:passive-latest

up:
	env IMAGE_TAG=${IMAGE_TAG} docker-compose up -d

down:
	env IMAGE_TAG=${IMAGE_TAG} docker-compose down

psql:
	docker-compose exec aidbox-db psql postgres
