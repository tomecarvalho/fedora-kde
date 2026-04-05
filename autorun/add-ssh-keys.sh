#!/usr/bin/env bash

# Add all SSH private keys (identified by having a matching .pub file) to the agent.

for file in ~/.ssh/*; do
    if [[ -f "$file" ]] && \
       [[ "$file" != *.pub ]] && \
       [[ -f "${file}.pub" ]]; then
        ssh-add "$file" 2>/dev/null
    fi
done