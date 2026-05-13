SHELL := /bin/bash

.DEFAULT_GOAL := help

UV ?= uv
ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ANSIBLE_DIR := $(ROOT_DIR)bootstrap/ansible
INVENTORY := inventory/asgard/hosts.yml
BOOTSTRAP_PLAYBOOK := playbooks/bootstrap.yml
DEPLOY_PLAYBOOK := playbooks/deploy-services.yml
ANSIBLE_PLAYBOOK := "$(UV)" run ansible-playbook -i "$(INVENTORY)"
ANSIBLE_PLAYBOOK_BECOME := $(ANSIBLE_PLAYBOOK) --ask-become-pass

.PHONY: \
	help \
	bootstrap \
	tools \
	validate \
	validate-all \
	ansible-sync \
	ansible-collections \
	ansible-syntax \
	ansible-lint \
	ansible-bootstrap \
	ansible-inventory \
	ansible-deploy-services \
	ansible-deploy-service

help:
	@printf "\nAsgard operator entrypoints\n\n"
	@printf "  bootstrap           Install local Ansible env and collections\n"
	@printf "  validate            Run core repo validation\n"
	@printf "\nAnsible\n"
	@printf "  ansible-sync        Create/update uv-managed Ansible environment\n"
	@printf "  ansible-collections Install required Ansible collections locally\n"
	@printf "  ansible-syntax      Run syntax checks for bootstrap and deploy playbooks\n"
	@printf "  ansible-lint        Run ansible-lint on bootstrap and deploy playbooks\n"
	@printf "  ansible-bootstrap   Bootstrap yggdrasil as a Docker host\n"
	@printf "  ansible-inventory   Print current inventory\n"
	@printf "  ansible-deploy-services Deploy all services with compose files under services/*\n"
	@printf "  ansible-deploy-service  Deploy one service, e.g. SERVICE=reverse-proxy\n\n"

tools:
	@command -v $(UV) >/dev/null 2>&1 || { echo "uv not found on PATH"; exit 1; }

bootstrap: tools ansible-sync ansible-collections

validate: ansible-syntax

validate-all: validate ansible-lint

ansible-sync: tools
	cd "$(ANSIBLE_DIR)" && "$(UV)" sync

ansible-collections: ansible-sync
	cd "$(ANSIBLE_DIR)" && "$(UV)" run ansible-galaxy collection install -r requirements.yml -p .ansible/collections

ansible-syntax: ansible-collections
	cd "$(ANSIBLE_DIR)" && $(ANSIBLE_PLAYBOOK) "$(BOOTSTRAP_PLAYBOOK)" --syntax-check
	cd "$(ANSIBLE_DIR)" && $(ANSIBLE_PLAYBOOK) "$(DEPLOY_PLAYBOOK)" --syntax-check

ansible-lint: ansible-collections
	cd "$(ANSIBLE_DIR)" && "$(UV)" run ansible-lint "$(BOOTSTRAP_PLAYBOOK)" "$(DEPLOY_PLAYBOOK)" playbooks/site.yml

ansible-bootstrap: ansible-collections
	cd "$(ANSIBLE_DIR)" && $(ANSIBLE_PLAYBOOK_BECOME) "$(BOOTSTRAP_PLAYBOOK)"

ansible-inventory: ansible-collections
	cd "$(ANSIBLE_DIR)" && "$(UV)" run ansible-inventory -i "$(INVENTORY)" --graph

ansible-deploy-services: ansible-collections
	cd "$(ANSIBLE_DIR)" && $(ANSIBLE_PLAYBOOK_BECOME) "$(DEPLOY_PLAYBOOK)" $(if $(SERVICES),-e docker_service_selector=$(SERVICES),)

ansible-deploy-service: ansible-collections
	@test -n "$(SERVICE)" || { echo "Set SERVICE=<name>"; exit 1; }
	cd "$(ANSIBLE_DIR)" && $(ANSIBLE_PLAYBOOK_BECOME) "$(DEPLOY_PLAYBOOK)" -e docker_service_selector=$(SERVICE)
