#!/bin/bash
# Ubuntu Meep provisioning module.

go_bin=$(go env GOBIN)
if [[ -z ${go_bin} ]]; then
	go_path=$(go env GOPATH)
	go_bin="${go_path%%:*}/bin"
fi
if [[ -x ${go_bin}/trello ]]; then
	echo "Already installed: trello; skipping."
else
	go install github.com/Scale-Flow/trello-cli/cmd/trello@latest
fi
