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
  assert_success "$platform config.json sets .llama.port" \
    jq -e '.llama.port | length > 0' "$RIG_REPO/unix/$platform/config.json"
done
assert_success "common rig-llama reads platform config.json" \
  grep -qF "unix/\$RIG_PLATFORM/config.json" "$RIG_REPO/unix/common/libexec/rig-llama"

section "rig-llama forwards flags regardless of position"

stub_dir=$(mktemp -d)
printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' > "$stub_dir/llama-cli"
chmod +x "$stub_dir/llama-cli"

PATH="$stub_dir:$PATH" LLAMA_MODELS_DIR="$stub_dir/models" \
  "$RIG_REPO/unix/common/libexec/rig-llama" chat --interactive ggml-org/test-model:Q4_0 > "$stub_dir/flag-first.out"
PATH="$stub_dir:$PATH" LLAMA_MODELS_DIR="$stub_dir/models" \
  "$RIG_REPO/unix/common/libexec/rig-llama" chat ggml-org/test-model:Q4_0 --interactive > "$stub_dir/flag-last.out"

assert_success "leading flag does not swallow model" \
  grep -q 'ggml-org/test-model:Q4_0' "$stub_dir/flag-first.out"
assert_success "-hf used with leading flag" \
  grep -q -e '-hf' "$stub_dir/flag-first.out"
assert_success "--interactive forwarded (leading flag)" \
  grep -q -- '--interactive' "$stub_dir/flag-first.out"
assert_success "--interactive forwarded (trailing flag)" \
  grep -q -- '--interactive' "$stub_dir/flag-last.out"
assert_success "model resolved when given first" \
  grep -q 'ggml-org/test-model:Q4_0' "$stub_dir/flag-last.out"

rm -rf "$stub_dir"

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
