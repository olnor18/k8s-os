DOCKER=docker

.DEFAULT_GOAL := build

docker-image:
	${DOCKER} build -t k8s-os .

build: docker-image
	${DOCKER} run --privileged --rm -t -i -v "$(PWD)":/k8s-os -w /k8s-os -e SUDO_UID=$(shell id -u) -e SUDO_GID=$(shell id -g) k8s-os ./build.sh

clean:
	rm -rf tmp output
