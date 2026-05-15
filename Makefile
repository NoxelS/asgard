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
WEBHOOK_URL ?= https://hooks.noel.fyi/hooks/deploy
REF ?= refs/heads/main

ifneq ($(filter webhook,$(MAKECMDGOALS)),)
WEBHOOK_POSITIONAL_REPO := $(word 2,$(MAKECMDGOALS))
ifneq ($(WEBHOOK_POSITIONAL_REPO),)
.PHONY: $(WEBHOOK_POSITIONAL_REPO)
$(WEBHOOK_POSITIONAL_REPO):
	@:
endif
endif

REPO ?= $(WEBHOOK_POSITIONAL_REPO)

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
	ansible-deploy-service \
	webhook

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
	@printf "Webhook\n"
	@printf "  webhook             Send signed deploy hook, e.g. make webhook NoxelS/portfolio REF=refs/heads/main\n"
	@printf "                      Also supports REPO=NoxelS/portfolio\n\n"

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

webhook:
	@test -n "$(REPO)" || { echo "Usage: make webhook NoxelS/portfolio REF=refs/heads/main"; exit 1; }
	@command -v sops >/dev/null 2>&1 || { echo "sops not found on PATH"; exit 1; }
	@command -v openssl >/dev/null 2>&1 || { echo "openssl not found on PATH"; exit 1; }
	@command -v xxd >/dev/null 2>&1 || { echo "xxd not found on PATH"; exit 1; }
	@case "$(REPO)" in ''|/*|*/*/*|*[!A-Za-z0-9._/-]*) echo "Invalid REPO; expected owner/name"; exit 1;; esac
	@case "$(REF)" in ''|-*|*[!A-Za-z0-9._/@:-]*|*..*|*@\{*) echo "Invalid REF"; exit 1;; esac
	@secret="$$(sops -d "$(ROOT_DIR)services/webhooks/secrets/webhook_secret")"; \
	payload="$$(printf '{"repository":"%s","ref":"%s"}' "$(REPO)" "$(REF)")"; \
	signature="sha256=$$(printf '%s' "$$payload" | openssl dgst -sha256 -hmac "$$secret" -binary | xxd -p -c 256)"; \
	curl --fail-with-body \
		--request POST \
		--header "Content-Type: application/json" \
		--header "X-Hub-Signature-256: $$signature" \
		--data "$$payload" \
		"$(WEBHOOK_URL)"
