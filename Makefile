.PHONY: init fmt validate plan apply plan-dev plan-prod apply-dev apply-prod ansible-deps ansible-ping ansible ansible-nfs ansible-argocd-bootstrap init-keycloak plan-keycloak apply-keycloak init-kong plan-kong apply-kong ci-tf sops-reencrypt

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
	cd ansible && ansible nginx -m ping -e @vars/sensitive.yml

ansible:
	cd ansible && ansible-playbook playbooks/site.yml -e @vars/sensitive.yml

ansible-nfs:
	cd ansible && ansible-playbook playbooks/nfs-server.yml -e @vars/sensitive.yml $(EXTRA_ARGS)

ansible-argocd-bootstrap: ansible-deps
	cd ansible && ansible-playbook playbooks/argocd-bootstrap.yml -e @vars/sensitive.yml

# Keycloak Terraform
init-keycloak:
	cd terraform/keycloak && ./run.sh $(ENV) init

plan-keycloak:
	cd terraform/keycloak && ./run.sh $(ENV) plan

apply-keycloak:
	cd terraform/keycloak && ./run.sh $(ENV) apply

# Kong Terraform
init-kong:
	cd terraform/kong && ./run.sh $(ENV) init

plan-kong:
	cd terraform/kong && ./run.sh $(ENV) plan

apply-kong:
	cd terraform/kong && ./run.sh $(ENV) apply

# SOPS - re-encrypt all tfvars after adding a new recipient to .sops.yaml
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
