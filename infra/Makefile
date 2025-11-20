.PHONY: init plan apply destroy

# Define variables for common options (optional)
TF_VARS_FILE ?= terraform.tfvars
TF_BACKEND_CONFIG ?= backend.tfvars

init:
	tofu init -backend-config="$(TF_BACKEND_CONFIG)"

plan:
	$(shell sh -c "source init.sh; tofu plan")

apply:
	$(shell sh -c "source init.sh; tofu apply")

destroy:
	$(shell sh -c "source init.sh; tofu destroy")
