APP := build/DevMonitor.app

.PHONY: help app run stop restart install test dump snapshot clean

help: ## List the commands
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

app: ## Build build/DevMonitor.app
	@./scripts/make-app.sh

run: app stop ## Build the app and launch it in the menu bar
	@open $(APP)

stop: ## Quit the app
	@pkill -u "$$(id -u)" -x DevMonitor || true

restart: run ## Rebuild and relaunch the app

install: ## Build the app, copy it to the Applications folder and launch it
	@./scripts/install.sh

test: ## Run the tests
	@swift test

dump: ## Print in the terminal what the app would show
	@swift run devmon-dump

snapshot: ## Render the memory and agents windows to build/
	@mkdir -p build && swift run devmon-snapshot build/snapshot.png && swift run devmon-snapshot build/agents.png agents && open build/snapshot.png build/agents.png

clean: ## Remove build output
	@rm -rf .build build
