#!/usr/bin/env bash
# Test cases sourced by run-tests.sh. Helpers (new_data_repo, assert_*, fail,
# SCRIPTS_DIR, WORK_DIR) come from the runner.

test_init_creates_week_files() {
    local repo
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    [[ -f "${repo}/weeks/2026-W46/inbox.md" ]] || fail "inbox.md missing"
    [[ -f "${repo}/weeks/2026-W46/log.md" ]] || fail "log.md missing"
    assert_contains "$(cat "${repo}/weeks/2026-W46/todos.md")" "# Todos — 2026-W46"
}

test_init_rejects_malformed_week_id() {
    local repo
    repo="$(new_data_repo)"
    if "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-46 2>/dev/null; then
        fail "malformed week id was accepted"
    fi
    [[ ! -d "${repo}/weeks" ]] || fail "weeks/ created despite invalid id"
}

test_init_carries_open_todos_and_increments_carry() {
    local repo todos
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W45 >/dev/null
    printf '%s\n' "- [ ] Call dentist #life added:2026-11-03" \
        "- [ ] Ship report #work !1 added:2026-11-01 carry:2" \
        "- [x] File taxes #life added:2026-11-02 done:2026-11-04" >> "${repo}/weeks/2026-W45/todos.md"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    todos="$(cat "${repo}/weeks/2026-W46/todos.md")"
    assert_contains "${todos}" "- [ ] Call dentist #life added:2026-11-03 carry:1"
    assert_contains "${todos}" "- [ ] Ship report #work !1 added:2026-11-01 carry:3"
    assert_not_contains "${todos}" "File taxes"
}

test_init_carries_from_latest_earlier_week_only() {
    local repo todos
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W40 >/dev/null
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W44 >/dev/null
    printf '%s\n' "- [ ] Old item #work" >> "${repo}/weeks/2026-W40/todos.md"
    printf '%s\n' "- [ ] Recent item #work" >> "${repo}/weeks/2026-W44/todos.md"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    todos="$(cat "${repo}/weeks/2026-W46/todos.md")"
    assert_contains "${todos}" "Recent item #work carry:1"
    assert_not_contains "${todos}" "Old item"
}

test_init_is_idempotent() {
    local repo
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    printf '%s\n' "- [ ] Keep me #work" >> "${repo}/weeks/2026-W46/todos.md"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null 2>&1
    assert_contains "$(cat "${repo}/weeks/2026-W46/todos.md")" "Keep me #work"
}

test_capture_appends_verbatim_multiline_text() {
    local repo inbox
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    # Literal $ and backticks must survive capture unexpanded.
    # shellcheck disable=SC2016
    printf 'um so first thing\n\nsecond paragraph $HOME `x`\n' \
        | "${SCRIPTS_DIR}/capture.sh" --root "${repo}" --week 2026-W46 2>/dev/null
    inbox="$(cat "${repo}/weeks/2026-W46/inbox.md")"
    assert_contains "${inbox}" "um so first thing"$'\n\n'"second paragraph \$HOME \`x\`"
    [[ "${inbox}" =~ \#\#\#\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z ]] || fail "missing timestamp heading"
}

test_capture_rejects_empty_input() {
    local repo
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    if printf '  \n' | "${SCRIPTS_DIR}/capture.sh" --root "${repo}" --week 2026-W46 2>/dev/null; then
        fail "empty capture was accepted"
    fi
}

test_capture_requires_initialized_week() {
    local repo
    repo="$(new_data_repo)"
    if printf 'hello\n' | "${SCRIPTS_DIR}/capture.sh" --root "${repo}" --week 2026-W46 2>/dev/null; then
        fail "capture succeeded without an initialized week"
    fi
}

test_stats_counts_todos_effort_and_captures() {
    local repo week_dir stats
    repo="$(new_data_repo)"
    week_dir="${repo}/weeks/2026-W46"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    printf '%s\n' "- [ ] A #work !1 carry:2" "- [ ] B #work" "- [x] C #work done:2026-11-16" \
        "- [ ] D #life/health carry:1" "- [ ] E no tag" >> "${week_dir}/todos.md"
    printf '%s\n' "- 2026-11-16 #work 45m deep work" "- 2026-11-16 #work 30m review" \
        "- 2026-11-17 #life walked" >> "${week_dir}/log.md"
    printf '%s\n' "### 2026-11-16T08:00Z" "x" "### 2026-11-16T19:00Z" "y" \
        "### 2026-11-17T07:00Z" "z" >> "${week_dir}/inbox.md"
    stats="$("${SCRIPTS_DIR}/week-stats.sh" --root "${repo}" --week 2026-W46)"
    assert_contains "${stats}" "| work | 2 | 1 | 1 | 1 | 2 | 75 |"
    assert_contains "${stats}" "| life | 1 | 0 | 0 | 0 | 1 | 0 |"
    assert_contains "${stats}" "| untagged | 1 | 0 | 0 | 0 | 0 | 0 |"
    assert_contains "${stats}" "- 2026-11-16: 2"
    assert_contains "${stats}" "- 2026-11-17: 1"
}

test_sync_commits_and_pushes_data() {
    local repo remote
    repo="$(new_data_repo)"
    remote="$(mktemp -d "${WORK_DIR}/remote.XXXXXX")"
    git -C "${remote}" init --quiet --bare
    git -C "${repo}" remote add origin "${remote}"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    "${SCRIPTS_DIR}/sync.sh" --root "${repo}" --message "capture: test" 2>/dev/null
    assert_contains "$(git -C "${remote}" log --oneline main)" "capture: test"
    assert_contains "$(git -C "${remote}" ls-tree -r --name-only main)" "weeks/2026-W46/todos.md"
}

test_sync_fails_loudly_when_push_impossible() {
    local repo
    repo="$(new_data_repo)"
    git -C "${repo}" remote add origin "${WORK_DIR}/does-not-exist"
    "${SCRIPTS_DIR}/week-init.sh" --root "${repo}" --week 2026-W46 >/dev/null
    if WEEKLY_SYNC_BACKOFF_SECONDS=0 "${SCRIPTS_DIR}/sync.sh" --root "${repo}" --message "m" 2>/dev/null; then
        fail "sync reported success with an unreachable remote"
    fi
    assert_contains "$(git -C "${repo}" log --oneline)" " m"
}

test_bootstrap_installs_skill_block_and_areas() {
    local repo
    repo="$(new_data_repo)"
    printf '# My notes\n' > "${repo}/CLAUDE.md"
    "${SCRIPTS_DIR}/bootstrap.sh" --target "${repo}" 2>/dev/null
    [[ -x "${repo}/.claude/skills/weekly-companion/scripts/sync.sh" ]] || fail "skill scripts not installed"
    assert_contains "$(cat "${repo}/CLAUDE.md")" "# My notes"
    assert_contains "$(cat "${repo}/CLAUDE.md")" "<!-- weekly-companion:start -->"
    [[ -f "${repo}/areas.md" ]] || fail "areas.md not seeded"
}

test_bootstrap_rerun_keeps_one_block_and_user_areas() {
    local repo block_count
    repo="$(new_data_repo)"
    "${SCRIPTS_DIR}/bootstrap.sh" --target "${repo}" 2>/dev/null
    printf 'my real goals\n' > "${repo}/areas.md"
    "${SCRIPTS_DIR}/bootstrap.sh" --target "${repo}" 2>/dev/null
    block_count="$(grep -c 'weekly-companion:start' "${repo}/CLAUDE.md")"
    ((block_count == 1)) || fail "expected 1 managed block, found ${block_count}"
    [[ "$(cat "${repo}/areas.md")" == "my real goals" ]] || fail "areas.md was overwritten"
}

test_bootstrap_rejects_non_git_target() {
    local plain_dir
    plain_dir="$(mktemp -d "${WORK_DIR}/plain.XXXXXX")"
    if "${SCRIPTS_DIR}/bootstrap.sh" --target "${plain_dir}" 2>/dev/null; then
        fail "bootstrap accepted a non-git directory"
    fi
}
