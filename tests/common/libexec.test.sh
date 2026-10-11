#!/bin/bash
section "libexec split: workers in libexec, bin holds only rig"

for platform in fedora macos; do
  bin_dir="$RIG_REPO/unix/$platform/bin"
  libexec_dir="$RIG_REPO/unix/$platform/libexec"

  # bin/ contains only the rig dispatcher
  for f in "$bin_dir"/*; do
    [[ -f "$f" ]] || continue
    assert_success "$platform bin/$(basename "$f") is the rig dispatcher" \
      test "$(basename "$f")" = "rig"
  done

  # no rig-* workers left in bin/
  assert_failure "$platform bin/ has no rig-* workers" \
    ls "$bin_dir"/rig-* 2>/dev/null

  # libexec/ holds only platform-specific workers; may be empty/absent (macos)
  if [[ -d "$libexec_dir" ]]; then
    assert_failure "$platform libexec/ has no rig-* duplicates of common workers" \
      ls "$libexec_dir"/rig-pkg-add "$libexec_dir"/rig-pkg-remove "$libexec_dir"/rig-drift 2>/dev/null
  fi

  # dispatcher resolves libexec
  assert_success "$platform dispatcher resolves libexec" \
    grep -q 'libexec' "$bin_dir/rig"
done

# common libexec holds shared workers
assert_success "common libexec/ has rig-* workers" \
  test -n "$(find "$RIG_REPO/unix/common/libexec" -maxdepth 1 -name 'rig-*' -print -quit)"

section "rig-ocr lives in common libexec with metadata"

script="$RIG_REPO/unix/common/libexec/rig-ocr"
assert_success "common rig-ocr is executable" test -x "$script"
assert_success "common rig-ocr has summary" grep -q 'rig:summary=' "$script"
assert_success "common rig-ocr has usage" grep -q 'rig:usage=' "$script"
assert_failure "no platform copies of rig-ocr remain" \
  ls "$RIG_REPO/unix/fedora/libexec/rig-ocr" "$RIG_REPO/unix/macos/libexec/rig-ocr" 2>/dev/null
assert_success "rig-ocr detects capture backend at runtime" \
  grep -q 'screencapture' "$script" && grep -q 'spectacle' "$script"

section "rig-llama lives in common libexec with metadata"

assert_success "common rig-llama exists" \
  test -x "$RIG_REPO/unix/common/libexec/rig-llama"
assert_success "common rig-llama has summary" \
  grep -q 'rig:summary=' "$RIG_REPO/unix/common/libexec/rig-llama"
assert_success "common rig-llama has usage" \
  grep -q 'rig:usage=' "$RIG_REPO/unix/common/libexec/rig-llama"
assert_failure "no platform copies of rig-llama remain" \
  ls "$RIG_REPO/unix/fedora/libexec/rig-llama" "$RIG_REPO/unix/macos/libexec/rig-llama" 2>/dev/null

section "rig-llama defaults come from config.json"

for platform in fedora macos; do
  assert_success "$platform config.json sets .llama.model" \
    jq -e '.llama.model | length > 0' "$RIG_REPO/unix/$platform/config.json"
  assert_success "$platform config.json models .llama.model as an array" \
    jq -e '.llama.model | type == "array"' "$RIG_REPO/unix/$platform/config.json"
  assert_success "$platform config.json sets .llama.port" \
    jq -e '.llama.port | length > 0' "$RIG_REPO/unix/$platform/config.json"
done
assert_success "common rig-llama reads platform config.json" \
  grep -qF "unix/\$RIG_PLATFORM/config.json" "$RIG_REPO/unix/common/libexec/rig-llama"

section "rig-llama takes the model only from arguments before the first flag"

mp_dir=$(mktemp -d)
mkdir -p "$mp_dir/unix/fedora" "$mp_dir/unix/common/libexec"
cp "$RIG_REPO/unix/common/libexec/rig-llama" "$mp_dir/unix/common/libexec/rig-llama"
chmod +x "$mp_dir/unix/common/libexec/rig-llama"
cat > "$mp_dir/unix/fedora/config.json" <<'JSON'
{
  "llama": {
    "model": ["orgorg/config-default:Q4_K_M"],
    "host": "127.0.0.1",
    "port": 8080
  }
}
JSON
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$mp_dir/llama-server"
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$mp_dir/llama-cli"
# Stub the remote reachability probe so tests never touch the network.
printf '#!/bin/bash\nexit 0\n' > "$mp_dir/curl"
chmod +x "$mp_dir/llama-server" "$mp_dir/llama-cli" "$mp_dir/curl"

mp_server() {
  RIG_PATH="$mp_dir" RIG_PLATFORM=fedora PATH="$mp_dir:$PATH" LLAMA_MODELS_DIR="$mp_dir/models" \
    "$mp_dir/unix/common/libexec/rig-llama" server "$@" > "$mp_dir/out" 2>&1 || true
}

# Model before the first flag wins over the config default.
mp_server orgorg/cli-model:Q4_K_M -ngl 20
assert_success "model before flags selects the model" grep -qx -- 'orgorg/cli-model:Q4_K_M' "$mp_dir/out"
assert_success "flag value after a model is forwarded" grep -qx -- '20' "$mp_dir/out"

# No model given: a flag value must not be mistaken for the model.
mp_server -ngl 20
assert_success "flag value is not mistaken for the model" grep -qx -- 'orgorg/config-default:Q4_K_M' "$mp_dir/out"
assert_success "flag value survives without a model" grep -qx -- '20' "$mp_dir/out"

mp_server --ctx-size 8192 -ngl 20
assert_success "config default survives two valued flags" grep -qx -- 'orgorg/config-default:Q4_K_M' "$mp_dir/out"
assert_success "--ctx-size value survives" grep -qx -- '8192' "$mp_dir/out"

# --model reaches llama-server untouched, so it works next to any flag.
mp_server --model /tmp/some-model.gguf
assert_success "--model is forwarded verbatim" grep -qx -- '/tmp/some-model.gguf' "$mp_dir/out"

# chat follows the same rule and falls back to the config default.
PATH="$mp_dir:$PATH" RIG_PATH="$mp_dir" RIG_PLATFORM=fedora LLAMA_MODELS_DIR="$mp_dir/models" \
  "$mp_dir/unix/common/libexec/rig-llama" chat --interactive > "$mp_dir/chat.out" 2>&1 || true
assert_success "chat falls back to the config default" grep -qx -- 'orgorg/config-default:Q4_K_M' "$mp_dir/chat.out"
assert_success "chat forwards --interactive" grep -qx -- '--interactive' "$mp_dir/chat.out"

rm -rf "$mp_dir"

section "rig-llama applies .llama.server_args from config.json"

for platform in fedora macos; do
  assert_success "$platform config.json sets .llama.server_args" \
    jq -e '.llama.server_args | length > 0' "$RIG_REPO/unix/$platform/config.json"
done

sa_dir=$(mktemp -d)
mkdir -p "$sa_dir/unix/fedora" "$sa_dir/unix/common/libexec"
cp "$RIG_REPO/unix/common/libexec/rig-llama" "$sa_dir/unix/common/libexec/rig-llama"
chmod +x "$sa_dir/unix/common/libexec/rig-llama"
cat > "$sa_dir/unix/fedora/config.json" <<'JSON'
{
  "llama": {
    "model": ["ggml-org/test-model:Q4_0"],
    "host": "127.0.0.1",
    "port": 8080,
    "server_args": ["-c", "2048", "-np", "1"]
  }
}
JSON
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$sa_dir/llama-server"
printf '#!/bin/bash\nexit 0\n' > "$sa_dir/curl"
chmod +x "$sa_dir/llama-server" "$sa_dir/curl"

RIG_PATH="$sa_dir" RIG_PLATFORM=fedora PATH="$sa_dir:$PATH" LLAMA_MODELS_DIR="$sa_dir/models" \
  "$sa_dir/unix/common/libexec/rig-llama" server --no-warmup > "$sa_dir/server.out" 2>&1 || true

assert_success "config server_args reach llama-server" grep -qx -- '-c' "$sa_dir/server.out"
assert_success "config server_args value reach llama-server" grep -qx -- '2048' "$sa_dir/server.out"
assert_success "config server_args -np reach llama-server" grep -qx -- '1' "$sa_dir/server.out"
assert_success "cli flag survives alongside config server_args" grep -qx -- '--no-warmup' "$sa_dir/server.out"

# Config args must come before CLI args so an explicit flag wins in llama-server.
sa_cfg_ctx=$(grep -nx -- '-c' "$sa_dir/server.out" | cut -d: -f1)
sa_cli_line=$(grep -nx -- '--no-warmup' "$sa_dir/server.out" | cut -d: -f1)
TOTAL=$((TOTAL + 1))
if [[ -n $sa_cfg_ctx && -n $sa_cli_line ]] && ((sa_cfg_ctx < sa_cli_line)); then
  echo -e "  ${TC_GREEN}✓${TC_RESET} config server_args are ordered before cli flags"
  PASS=$((PASS + 1))
else
  echo -e "  ${TC_RED}✗${TC_RESET} config server_args are ordered before cli flags"
  FAIL=$((FAIL + 1))
fi

rm -rf "$sa_dir"

section "rig-llama tolerates a config.json without .llama.server_args"

nb_dir=$(mktemp -d)
mkdir -p "$nb_dir/unix/fedora" "$nb_dir/unix/common/libexec"
cp "$RIG_REPO/unix/common/libexec/rig-llama" "$nb_dir/unix/common/libexec/rig-llama"
chmod +x "$nb_dir/unix/common/libexec/rig-llama"
cat > "$nb_dir/unix/fedora/config.json" <<'JSON'
{
  "llama": {
    "model": ["ggml-org/test-model:Q4_0"],
    "host": "127.0.0.1",
    "port": 8080
  }
}
JSON
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$nb_dir/llama-server"
printf '#!/bin/bash\nexit 0\n' > "$nb_dir/curl"
chmod +x "$nb_dir/llama-server" "$nb_dir/curl"

assert_success "server runs with no server_args key" \
  env RIG_PATH="$nb_dir" RIG_PLATFORM=fedora PATH="$nb_dir:$PATH" \
    LLAMA_MODELS_DIR="$nb_dir/models" "$nb_dir/unix/common/libexec/rig-llama" server
assert_output_not_contains "no empty argument leaks into llama-server" "()" \
  cat "$nb_dir/llama-server"

rm -rf "$nb_dir"

section "rig-llama walks the .llama.model chain in order"

fc_dir=$(mktemp -d)
mkdir -p "$fc_dir/unix/fedora" "$fc_dir/unix/common/libexec" "$fc_dir/models"
cp "$RIG_REPO/unix/common/libexec/rig-llama" "$fc_dir/unix/common/libexec/rig-llama"
chmod +x "$fc_dir/unix/common/libexec/rig-llama"
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$fc_dir/llama-server"
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$fc_dir/llama-cli"
chmod +x "$fc_dir/llama-server" "$fc_dir/llama-cli"
printf '#!/bin/bash\nexit 0\n' > "$fc_dir/curl_ok"
chmod +x "$fc_dir/curl_ok"

# A real local file in the models dir proves the first entry wins.
: > "$fc_dir/models/local-first.gguf"

fc_write_config() {
  cat > "$fc_dir/unix/fedora/config.json" <<JSON
{
  "llama": {
    "model": $1,
    "host": "127.0.0.1",
    "port": 8080
  }
}
JSON
}

fc_run() {
  RIG_PATH="$fc_dir" RIG_PLATFORM=fedora PATH="$fc_dir:$PATH" LLAMA_MODELS_DIR="$fc_dir/models" \
    "$fc_dir/unix/common/libexec/rig-llama" server "$@" > "$fc_dir/out" 2>&1 || true
}

# First usable entry wins over later entries.
fc_write_config '["local-first.gguf", "orgorg/second:Q4_K_M"]'
fc_run
assert_success "first usable chain entry is chosen" grep -qx -- '--model' "$fc_dir/out"
assert_success "first chain entry resolves to the models dir" grep -qx -- "$fc_dir/models/local-first.gguf" "$fc_dir/out"
assert_success "usable first entry produces no skip warning" \
  bash -c "! grep -q 'Skipping unusable' '$fc_dir/out'"

# An unusable first entry is skipped and the next usable one wins.
fc_write_config '["missing.gguf", "local-first.gguf"]'
fc_run
assert_success "unusable chain entry is skipped" grep -q 'Skipping unusable model: missing.gguf' "$fc_dir/out"
assert_success "chain falls through to the next usable entry" grep -qx -- "$fc_dir/models/local-first.gguf" "$fc_dir/out"

# A missing first entry plus a missing second entry still fails loudly.
fc_write_config '["missing-a.gguf", "missing-b.gguf"]'
fc_run
assert_success "exhausted chain reports an error" grep -q 'No usable model' "$fc_dir/out"

# An empty chain is an error, not a silent success.
fc_write_config '[]'
fc_run
assert_success "empty chain reports an error" grep -q 'No model given' "$fc_dir/out"

# An explicit argument does not fall back to the chain.
fc_write_config '["local-first.gguf"]'
fc_run "no-such-model.gguf"
assert_success "explicit model failure does not use the chain" grep -q 'Model not found or unavailable' "$fc_dir/out"
assert_success "explicit model failure skips no chain entry" \
  bash -c "! grep -q 'Skipping unusable' '$fc_dir/out'"

# A remote ref that the probe rejects is skipped like any other bad entry.
printf '#!/bin/bash\nexit 1\n' > "$fc_dir/curl"
chmod +x "$fc_dir/curl"
fc_write_config '["orgorg/gone:Q4_K_M", "local-first.gguf"]'
fc_run
assert_success "unreachable remote entry is skipped" grep -q 'Skipping unusable model: orgorg/gone:Q4_K_M' "$fc_dir/out"
assert_success "unreachable remote entry falls through" grep -qx -- "$fc_dir/models/local-first.gguf" "$fc_dir/out"

# A cached remote model needs no probe, so it stays usable offline.
fc_cache="$fc_dir/home/.cache/huggingface/hub/models--orgorg--cached/snapshots/abc"
mkdir -p "$fc_cache"
: > "$fc_cache/model.gguf"
fc_write_config '["orgorg/cached:Q4_K_M"]'
XDG_CACHE_HOME="$fc_dir/home/.cache" fc_run
assert_success "cached remote model needs no probe" grep -qx -- '-hf' "$fc_dir/out"
assert_success "cached remote model is used" grep -qx -- 'orgorg/cached:Q4_K_M' "$fc_dir/out"

rm -rf "$fc_dir"

section "rig-llama list shows the chain and downloaded models"

fl_dir=$(mktemp -d)
mkdir -p "$fl_dir/unix/fedora" "$fl_dir/unix/common/libexec" "$fl_dir/models"
cp "$RIG_REPO/unix/common/libexec/rig-llama" "$fl_dir/unix/common/libexec/rig-llama"
chmod +x "$fl_dir/unix/common/libexec/rig-llama"
: > "$fl_dir/models/downloaded.gguf"
cat > "$fl_dir/unix/fedora/config.json" <<'JSON'
{
  "llama": {
    "model": ["orgorg/one:Q4_K_M", "orgorg/two:Q4_K_M"],
    "host": "127.0.0.1",
    "port": 8080
  }
}
JSON

RIG_PATH="$fl_dir" RIG_PLATFORM=fedora LLAMA_MODELS_DIR="$fl_dir/models" \
  "$fl_dir/unix/common/libexec/rig-llama" list > "$fl_dir/list.out" 2>&1
assert_output_contains "list shows a configured chain entry" "orgorg/one:Q4_K_M" cat "$fl_dir/list.out"
assert_output_contains "list shows the second chain entry" "orgorg/two:Q4_K_M" cat "$fl_dir/list.out"
assert_output_contains "list shows downloaded models" "downloaded.gguf" cat "$fl_dir/list.out"

rm -rf "$fl_dir"

section "rig-llama system-prompt proxy wiring"

proxy="$RIG_REPO/unix/common/libexec/rig-llama-proxy"
assert_success "rig-llama-proxy is executable" test -x "$proxy"

for platform in fedora macos; do
  assert_success "$platform config.json sets .llama.system_prompt_file" \
    jq -e '.llama.system_prompt_file | length > 0' "$RIG_REPO/unix/$platform/config.json"
done
assert_success "rig-llama references the prompt file config" \
  grep -q 'system_prompt_file' "$RIG_REPO/unix/common/libexec/rig-llama"

python3 -m py_compile "$proxy"
assert_success "rig-llama-proxy compiles" python3 -m py_compile "$proxy"
assert_success "rig-llama-proxy self-test passes" "$proxy" --self-test

section "rig-install runs modules through the platform setup script"

install_cmd="$RIG_REPO/unix/common/libexec/rig-install"
assert_success "common rig-install is executable" test -x "$install_cmd"
assert_success "common rig-install has summary" grep -q 'rig:summary=' "$install_cmd"
assert_success "common rig-install has usage" grep -q 'rig:usage=' "$install_cmd"
assert_failure "no platform copies of rig-install remain" \
  ls "$RIG_REPO/unix/fedora/libexec/rig-install" "$RIG_REPO/unix/macos/libexec/rig-install" 2>/dev/null

assert_output_contains "no arguments prints usage" "Usage: rig install" "$install_cmd"
assert_output_contains "--help points at the platform setup script" "-setup --only" "$install_cmd" --help

# --list must print runnable module names, so no line may keep the .sh suffix
# and non-module payload files must not appear.
list_file=$(mktemp)
"$install_cmd" --list > "$list_file" 2>&1
assert_success "--list prints module paths" grep -qE '^config/' "$list_file"
assert_failure "--list omits .sh payload files" grep -q '\.sh$' "$list_file"
rm -f "$list_file"
