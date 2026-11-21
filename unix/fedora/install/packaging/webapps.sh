#!/bin/bash

source "$RIG_INSTALL/helpers/logging.sh"

log_section "Web Applications"

# ChatGPT
log_info "Installing ChatGPT web app..."
rig-webapp-install "ChatGPT" \
  "https://chatgpt.com/" \
  "https://cdn.oaistatic.com/_next/static/media/apple-touch-icon.59f2e898.png"

# Scira
log_info "Installing Scira web app..."
rig-webapp-install "Scira" \
  "https://scira.ai/" \
  "https://scira.ai/favicon.ico"

log_success "Web applications installed"
