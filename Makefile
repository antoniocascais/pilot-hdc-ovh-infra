.PHONY: init fmt validate plan apply plan-dev plan-prod apply-dev apply-prod ansible-deps ansible-ping ansible ansible-nfs ansible-freeipa ansible-guacamole ansible-argocd-bootstrap ansible-lint init-keycloak plan-keycloak apply-keycloak init-kong plan-kong apply-kong ci-tf sops-reencrypt

# Environment (default: dev)
ENV ?= dev

# Terraform (per-environment)
init:
	cd terraform && ./run.sh $(ENV) init

fmt:
	cd terraform && terraform fmt -recursive

validate:
	cd terraform && terraform validate

plan:
	cd terraform && ./run.sh $(ENV) plan

apply:
	cd terraform && ./run.sh $(ENV) apply

# Shortcuts
plan-dev:
	$(MAKE) plan ENV=dev

plan-prod:
	$(MAKE) plan ENV=prod

apply-dev:
	$(MAKE) apply ENV=dev

apply-prod:
	$(MAKE) apply ENV=prod

# Ansible
ansible-deps:
	pip install -r ansible/requirements.txt
	ansible-galaxy collection install -r ansible/requirements.yml

ansible-ping:
	./ansible/run.sh ansible nginx -m ping

ansible:
	./ansible/run.sh ansible-playbook playbooks/site.yml $(EXTRA_ARGS)

ansible-nfs:
	./ansible/run.sh ansible-playbook playbooks/nfs-server.yml $(EXTRA_ARGS)

ansible-freeipa:
	./ansible/run.sh ansible-playbook playbooks/freeipa-server.yml $(EXTRA_ARGS)

ansible-guacamole:
	./ansible/run.sh ansible-playbook playbooks/guacamole-vm.yml $(EXTRA_ARGS)

ansible-argocd-bootstrap: ansible-deps
	./ansible/run.sh ansible-playbook playbooks/argocd-bootstrap.yml $(EXTRA_ARGS)

ansible-lint:
	docker run --rm -v "$$(pwd)":/work -w /work python:3.12-slim bash -c \
		"pip install -q ansible-core ansible-lint yamllint && \
		 ansible-galaxy collection install -r ansible/requirements.yml && \
		 yamllint ansible/ && \
		 ansible-lint ansible/"

# Keycloak Terraform
init-keycloak:
	cd terraform/keycloak && ./run.sh $(ENV) init

plan-keycloak:
	cd terraform/keycloak && ./run.sh $(ENV) plan

apply-keycloak:
	cd terraform/keycloak && ./run.sh $(ENV) apply

# Kong Terraform (manual only — not in CI)
# Apply: export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
#        make plan-kong && make apply-kong
init-kong:
	cd terraform/kong && ./run.sh $(ENV) init

plan-kong:
	cd terraform/kong && ./run.sh $(ENV) plan

apply-kong:
	cd terraform/kong && ./run.sh $(ENV) apply

# SOPS - re-encrypt all secrets after adding a new recipient to .sops.yaml
sops-reencrypt:
	@find terraform -name '*.tfvars' -not -path '*/bootstrap/*' | while read f; do \
		echo "Re-encrypting $$f"; \
		plain=$$(mktemp --suffix=.tfvars); \
		enc=$$(mktemp --suffix=.tfvars); \
		sops -d --input-type dotenv --output-type dotenv "$$f" > "$$plain" && \
		sops -e --input-type dotenv --output-type dotenv "$$plain" > "$$enc" && \
		mv "$$enc" "$$f"; \
		rm -f "$$plain" "$$enc"; \
	done
	@echo "Re-encrypting ansible/vars/sensitive.yml"; \
	sops updatekeys -y ansible/vars/sensitive.yml

# CI - Terraform static analysis
ci-tf:
	@for cmd in terraform tflint checkov; do \
		command -v $$cmd >/dev/null || { echo "ERROR: $$cmd not found"; exit 1; }; \
	done
	cd terraform && terraform fmt -check
	cd terraform/keycloak && terraform fmt -check
	cd terraform/kong && terraform fmt -check
	cd terraform && terraform validate
	cd terraform/keycloak && terraform validate
	tflint --recursive terraform/
	checkov -d terraform/
