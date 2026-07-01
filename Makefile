.PHONY: init plan apply apply-auto destroy fmt fmt-check validate workflow-check check state-list refresh

init:
	@mise run init

plan:
	@mise run plan

apply:
	@mise run apply

apply-auto:
	@mise run apply-auto

destroy:
	@mise run destroy

fmt:
	@mise run fmt

fmt-check:
	@mise run fmt-check

validate:
	@mise run validate

workflow-check:
	@mise run workflow-check

check:
	@mise run check

state-list:
	@mise run state-list

refresh:
	@mise run refresh
