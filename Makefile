.PHONY: init fmt validate plan apply plan-dev plan-prod apply-dev apply-prod ansible-deps ansible-ping ansible ansible-argocd-bootstrap

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

ansible-argocd-bootstrap: ansible-deps
	cd ansible && ansible-playbook playbooks/argocd-bootstrap.yml -e @vars/sensitive.yml
