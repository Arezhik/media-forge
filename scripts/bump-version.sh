#!/usr/bin/env bash
# bump-version.sh: keep one app's version in sync everywhere it lives.
#
# Usage (from the repo root):
#   scripts/bump-version.sh <app> patch|minor|major [--dry-run]
#                                                       bump, build +1, CHANGELOG stub
#   scripts/bump-version.sh <app> --check               fail if the places disagree
#   scripts/bump-version.sh <app> --current             print "X.Y.Z (build N)"
#   scripts/bump-version.sh <app> --check-against <ref> fail unless the build is above <ref>'s,
#                                                       or the version and build are unchanged
#   scripts/bump-version.sh <app> --rebase <ref> patch|minor|major [--dry-run]
#                                                       redo this branch's bump on top of <ref>
#                                                       (for example origin/main after another
#                                                       PR merged a bump first)
#
# <app> is exactly one of: mkvforge, mp4subrip, pgs2srt.
# Apps/<App>/scripts/bump-version.sh is a wrapper that adds the app name and
# forwards every argument here.
#
# Rules (Semantic Versioning, MAJOR.MINOR.PATCH):
#   patch  bug fix or small tweak                 0.1.0 -> 0.1.1
#   minor  normal enhancement or new feature      0.1.1 -> 0.2.0
#   major  major enhancement or breaking change   0.2.0 -> 1.0.0
#   A new phase is usually a minor bump; 1.0.0 is the v1 release.
#   Every bump also adds 1 to the build number. Docs-only or CI-only PRs don't bump.
#   Tags: per-app <app>-vX.Y.Z (mkvforge-vX.Y.Z, mp4subrip-vX.Y.Z, pgs2srt-vX.Y.Z).
#   Never a bare vX.Y.Z.
#
# Two open PRs that both bump collide on the same version lines. Whichever merges
# second: merge or rebase onto main (take either side of the version-line conflicts),
# then run `--rebase origin/main <rule>`. It sets the version to main's version plus
# <rule>, the build to main's build + 1, and renames this branch's CHANGELOG section
# (the first one that main doesn't have) to match. See Apps/MKVForge/docs/LESSONS.md L20.
#
# The version lives in: App/*.xcodeproj/project.pbxproj (MARKETING_VERSION and
# CURRENT_PROJECT_VERSION, Debug and Release) and App/project.yml (the same keys).
# MKV Forge and MP4SubRip also require CHANGELOG.md. PGS2SRT has no CHANGELOG.md;
# --check still requires project.pbxproj and project.yml to agree, and a bump does
# not create a changelog. --check-against allows an unchanged version and build
# (docs-only or CI-only). The build must rise when the version changes, and the
# build must not go down. Info.plist has no version keys; Xcode generates them from
# the build settings. Works with macOS's bash 3.2 and BSD sed/awk, and with GNU tools.
set -eu

die() { echo "bump-version: $*" >&2; exit 1; }

show_help() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

if [ $# -eq 0 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  show_help
  if [ $# -eq 0 ]; then
    exit 1
  fi
  exit 0
fi

APP="$1"
shift
case "$APP" in
  mkvforge)
    APP_DIR="Apps/MKVForge"
    TAG_PREFIX="mkvforge-v"
    CHANGELOG_REQUIRED=1
    ;;
  mp4subrip)
    APP_DIR="Apps/MP4SubRip"
    TAG_PREFIX="mp4subrip-v"
    CHANGELOG_REQUIRED=1
    ;;
  pgs2srt)
    APP_DIR="Apps/PGS2SRT"
    TAG_PREFIX="pgs2srt-v"
    CHANGELOG_REQUIRED=0
    ;;
  *) die "unknown app '$APP' (use mkvforge, mp4subrip, or pgs2srt)" ;;
esac

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="$REPO/$APP_DIR"
PBX="$(ls -1 "$APP_ROOT"/App/*.xcodeproj/project.pbxproj 2>/dev/null | head -1 || true)"
YML="$APP_ROOT/App/project.yml"
LOG="$APP_ROOT/CHANGELOG.md"

# Git tree prefix of this app, with a trailing slash (Apps/MKVForge/).
# `git show REF:path` paths start at the git root, so app-relative paths need it.
# Empty when this directory is the git root. `--show-prefix` follows cwd via -C.
if git -C "$APP_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_PREFIX="$(git -C "$APP_ROOT" rev-parse --show-prefix 2>/dev/null || true)"
else
  GIT_PREFIX=""
fi
git_path() { printf '%s%s' "$GIT_PREFIX" "$1"; }

[ -n "$PBX" ] && [ -f "$PBX" ] || die "no App/*.xcodeproj/project.pbxproj found under $APP_ROOT"

# Distinct values of a key in a file, one per line.
pbx_values() { sed -n "s/^[[:space:]]*$1 = \"\{0,1\}\([^\";]*\)\"\{0,1\};.*/\1/p" "$PBX" | sort -u; }
yml_values() { [ -f "$YML" ] || return 0; sed -n "s/^[[:space:]]*$1:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$/\1/p" "$YML" | sort -u; }

read_current() {
  [ -f "$YML" ] || die "App/project.yml is missing under $APP_ROOT"
  V_PBX="$(pbx_values MARKETING_VERSION)"
  B_PBX="$(pbx_values CURRENT_PROJECT_VERSION)"
  V_YML="$(yml_values MARKETING_VERSION)"
  B_YML="$(yml_values CURRENT_PROJECT_VERSION)"
  [ -n "$V_PBX" ] || die "MARKETING_VERSION not found in $PBX"
  [ -n "$B_PBX" ] || die "CURRENT_PROJECT_VERSION not found in $PBX"
  [ "$(printf '%s\n' "$V_PBX" | wc -l | tr -d ' ')" = 1 ] || die "project.pbxproj has different MARKETING_VERSION values: $(echo $V_PBX)"
  [ "$(printf '%s\n' "$B_PBX" | wc -l | tr -d ' ')" = 1 ] || die "project.pbxproj has different CURRENT_PROJECT_VERSION values: $(echo $B_PBX)"
  [ "$V_YML" = "$V_PBX" ] || die "App/project.yml MARKETING_VERSION ($(echo $V_YML)) != project.pbxproj ($V_PBX)"
  [ "$B_YML" = "$B_PBX" ] || die "App/project.yml CURRENT_PROJECT_VERSION ($(echo $B_YML)) != project.pbxproj ($B_PBX)"
  printf '%s' "$V_PBX" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || die "MARKETING_VERSION $V_PBX is not MAJOR.MINOR.PATCH"
  printf '%s' "$B_PBX" | grep -Eq '^[0-9]+$' || die "CURRENT_PROJECT_VERSION $B_PBX is not a whole number"
  VERSION="$V_PBX"; BUILD="$B_PBX"
}

check_changelog() {
  if [ ! -f "$LOG" ]; then
    if [ "$CHANGELOG_REQUIRED" -eq 1 ]; then
      die "CHANGELOG.md is missing"
    fi
    return 0
  fi
  grep -q "^## \[$VERSION\]" "$LOG" || die "CHANGELOG.md has no '## [$VERSION]' entry"
}

sync_message() {
  if [ -f "$LOG" ]; then
    echo "Version $VERSION (build $BUILD) is in sync in project.pbxproj, project.yml, and CHANGELOG.md"
  else
    echo "Version $VERSION (build $BUILD) is in sync in project.pbxproj and project.yml"
  fi
}

replace_in() { # file sed-expression
  sed -e "$2" "$1" > "$1.tmp" && cat "$1.tmp" > "$1" && rm -f "$1.tmp"
}

# Version and build at a git ref (for example origin/main), from that ref's pbxproj.
# When App/project.yml exists at the ref, it must agree with the pbxproj.
read_ref() { # ref
  command -v git >/dev/null 2>&1 || die "git is needed for $1"
  REL="$(git_path "${PBX#$APP_ROOT/}")"
  REF_PBX="$(git -C "$APP_ROOT" show "$1:$REL" 2>/dev/null)" || die "can't read $REL at $1 (fetch it first, for example: git fetch origin main)"
  REF_VERSION="$(printf '%s\n' "$REF_PBX" | sed -n 's/^[[:space:]]*MARKETING_VERSION = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' | sort -u)"
  REF_BUILD="$(printf '%s\n' "$REF_PBX" | sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' | sort -u)"
  [ "$(printf '%s\n' "$REF_VERSION" | wc -l | tr -d ' ')" = 1 ] && [ -n "$REF_VERSION" ] || die "$1 has no single MARKETING_VERSION"
  [ "$(printf '%s\n' "$REF_BUILD" | wc -l | tr -d ' ')" = 1 ] && [ -n "$REF_BUILD" ] || die "$1 has no single CURRENT_PROJECT_VERSION"
  YML_REL="$(git_path "${YML#$APP_ROOT/}")"
  if git -C "$APP_ROOT" cat-file -e "$1:$YML_REL" 2>/dev/null; then
    REF_YML="$(git -C "$APP_ROOT" show "$1:$YML_REL" 2>/dev/null)" || die "can't read $YML_REL at $1"
    REF_YML_V="$(printf '%s\n' "$REF_YML" | sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' | sort -u)"
    REF_YML_B="$(printf '%s\n' "$REF_YML" | sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' | sort -u)"
    [ "$(printf '%s\n' "$REF_YML_V" | wc -l | tr -d ' ')" = 1 ] && [ -n "$REF_YML_V" ] || die "$1 App/project.yml has no single MARKETING_VERSION"
    [ "$(printf '%s\n' "$REF_YML_B" | wc -l | tr -d ' ')" = 1 ] && [ -n "$REF_YML_B" ] || die "$1 App/project.yml has no single CURRENT_PROJECT_VERSION"
    [ "$REF_YML_V" = "$REF_VERSION" ] || die "$1 App/project.yml MARKETING_VERSION ($REF_YML_V) != project.pbxproj ($REF_VERSION)"
    [ "$REF_YML_B" = "$REF_BUILD" ] || die "$1 App/project.yml CURRENT_PROJECT_VERSION ($REF_YML_B) != project.pbxproj ($REF_BUILD)"
  fi
  REF_LOG="$(git -C "$APP_ROOT" show "$1:$(git_path CHANGELOG.md)" 2>/dev/null || true)"
}

MODE="${1:-}"
DRY=0
REBASE_REF=""
BRANCH_HEAD=""
case "$MODE" in
  --current) read_current; echo "$VERSION (build $BUILD)"; exit 0 ;;
  --check) read_current; check_changelog; sync_message; exit 0 ;;
  --check-against)
    [ -n "${2:-}" ] || die "--check-against needs a git ref, such as origin/main"
    read_current; check_changelog
    # The first PR (the generated project) has no project file on the base branch yet.
    # The ref itself must exist; only a missing pbxproj there counts as "no version yet".
    command -v git >/dev/null 2>&1 || die "git is needed for $2"
    git -C "$APP_ROOT" rev-parse --verify --quiet "$2^{commit}" >/dev/null || die "can't read $2 (fetch it first, for example: git fetch origin main)"
    if ! git -C "$APP_ROOT" cat-file -e "$2:$(git_path "${PBX#$APP_ROOT/}")" 2>/dev/null; then
      echo "$2 has no $(git_path "${PBX#$APP_ROOT/}") yet (first version). This branch starts at $VERSION (build $BUILD)"; exit 0
    fi
    read_ref "$2"
    if [ "$BUILD" -gt "$REF_BUILD" ]; then
      echo "Build $BUILD is above $2's build $REF_BUILD ($VERSION vs $REF_VERSION)"; exit 0
    fi
    if [ "$BUILD" = "$REF_BUILD" ] && [ "$VERSION" = "$REF_VERSION" ]; then
      echo "No version bump on this branch ($VERSION, build $BUILD, same as $2)"; exit 0
    fi
    die "this branch is $VERSION (build $BUILD) but $2 is $REF_VERSION (build $REF_BUILD). Another PR bumped first. Run: scripts/bump-version.sh $APP --rebase $2 patch|minor|major"
    ;;
  --rebase)
    REBASE_REF="${2:-}"; MODE="${3:-}"
    [ -n "$REBASE_REF" ] || die "--rebase needs a git ref and a rule, such as: --rebase origin/main patch"
    [ "${4:-}" = "--dry-run" ] && DRY=1
    case "$MODE" in patch|minor|major) ;; *) die "--rebase needs patch, minor, or major after the ref" ;; esac
    ;;
  patch|minor|major) [ "${2:-}" = "--dry-run" ] && DRY=1 ;;
  -h|--help|"") show_help; [ -n "$MODE" ]; exit $? ;;
  *) die "unknown option $MODE (use patch, minor, major, --check, --check-against, --rebase, or --current)" ;;
esac

if [ -n "$REBASE_REF" ]; then
  read_ref "$REBASE_REF"
  if [ "$DRY" -eq 1 ]; then
    VERSION="$REF_VERSION"; BUILD="$REF_BUILD"; SKIP_READ=1
  else
    # The working tree may hold this branch's old bump, main's numbers, or a mix after a
    # conflict. Overwrite every version line with one value first, then bump from main.
    BR_PBX_V="$(pbx_values MARKETING_VERSION | head -1)"
    replace_in "$PBX" "s/\(MARKETING_VERSION = \)\"\{0,1\}[^\";]*\"\{0,1\};/\1$REF_VERSION;/; s/\(CURRENT_PROJECT_VERSION = \)\"\{0,1\}[^\";]*\"\{0,1\};/\1$REF_BUILD;/"
    if [ -f "$YML" ]; then
      replace_in "$YML" "s/\(MARKETING_VERSION:[[:space:]]*\).*\$/\1\"$REF_VERSION\"/; s/\(CURRENT_PROJECT_VERSION:[[:space:]]*\).*\$/\1\"$REF_BUILD\"/"
    fi
    # This branch's own CHANGELOG section: the first "## [x.y.z]" heading that the ref doesn't have.
    if [ -f "$LOG" ]; then
      REF_HEADS="$(printf '%s\n' "$REF_LOG" | sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p')"
      for v in $(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' "$LOG"); do
        if ! printf '%s\n' "$REF_HEADS" | grep -qx "$v"; then BRANCH_HEAD="$v"; break; fi
      done
    fi
    echo "Rebasing the bump onto $REBASE_REF ($REF_VERSION, build $REF_BUILD); this branch had ${BR_PBX_V:-?}"
  fi
fi

[ "${SKIP_READ:-0}" = 1 ] || read_current
MAJ="${VERSION%%.*}"; REST="${VERSION#*.}"; MIN="${REST%%.*}"; PAT="${REST#*.}"
case "$MODE" in
  patch) PAT=$((PAT + 1)) ;;
  minor) MIN=$((MIN + 1)); PAT=0 ;;
  major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
esac
NEW="$MAJ.$MIN.$PAT"
OLD="$VERSION"; OLDBUILD="$BUILD"
NEWBUILD=$((BUILD + 1))
case "$MODE" in
  patch) RULE="patch: bug fix or small tweak"; SECTION="Fixed" ;;
  minor) RULE="minor: enhancement or new feature"; SECTION="Added" ;;
  major) RULE="major: major enhancement or breaking change"; SECTION="Added" ;;
esac
echo "Version bump: $OLD (build $OLDBUILD) to $NEW (build $NEWBUILD) ($RULE)"
[ "$DRY" -eq 1 ] && exit 0

replace_in "$PBX" "s/\(MARKETING_VERSION = \)\"\{0,1\}$VERSION\"\{0,1\};/\1$NEW;/; s/\(CURRENT_PROJECT_VERSION = \)\"\{0,1\}$BUILD\"\{0,1\};/\1$NEWBUILD;/"
if [ -f "$YML" ]; then
  replace_in "$YML" "s/\(MARKETING_VERSION:[[:space:]]*\)\"$VERSION\"/\1\"$NEW\"/; s/\(MARKETING_VERSION:[[:space:]]*\)$VERSION\$/\1\"$NEW\"/; s/\(CURRENT_PROJECT_VERSION:[[:space:]]*\)\"$BUILD\"/\1\"$NEWBUILD\"/; s/\(CURRENT_PROJECT_VERSION:[[:space:]]*\)$BUILD\$/\1\"$NEWBUILD\"/"
fi

# CHANGELOG: add a stub section for the new version under [Unreleased].
# PGS2SRT has no CHANGELOG.md. Do not create one.
write_changelog() {
  if [ ! -f "$LOG" ] && [ "$CHANGELOG_REQUIRED" -eq 0 ]; then
    return 0
  fi
  TODAY="$(date +%Y-%m-%d)"
  if [ ! -f "$LOG" ]; then
    printf '# Changelog\n\nAll notable changes to this app. Format: https://keepachangelog.com/en/1.1.0/ Versions: https://semver.org/\n\n## [Unreleased]\n' > "$LOG"
  fi
  if [ -n "$REBASE_REF" ] && [ -n "$BRANCH_HEAD" ]; then
    # Keep this branch's notes; only the heading changes.
    awk -v old="$BRANCH_HEAD" -v new="$NEW" -v day="$TODAY" -v build="$NEWBUILD" '
      !done && index($0, "## [" old "]") == 1 { print "## [" new "] - " day " (build " build ")"; done = 1; next }
      { print }
    ' "$LOG" > "$LOG.tmp" && cat "$LOG.tmp" > "$LOG" && rm -f "$LOG.tmp"
    echo "CHANGELOG: renamed this branch's section [$BRANCH_HEAD] to [$NEW] (build $NEWBUILD)"
  else
    STUB="$(mktemp "${TMPDIR:-/tmp}/bump-version.XXXXXX")"
    trap 'rm -f "$STUB"' EXIT
    printf '## [%s] - %s (build %s)\n### %s\n- TODO: one line per user-visible change, with the PR or issue number.\n\n' "$NEW" "$TODAY" "$NEWBUILD" "$SECTION" > "$STUB"
    awk -v stub="$STUB" '
      function emit() { while ((getline line < stub) > 0) print line; done = 1 }
      /^## \[Unreleased\]/ { print; seen = 1; next }
      seen && !done && /^## \[/ { emit() }
      { print }
      END { if (!done) { if (!seen) print "## [Unreleased]"; print ""; emit() } }
    ' "$LOG" > "$LOG.tmp" && cat "$LOG.tmp" > "$LOG" && rm -f "$LOG.tmp"
  fi
}
write_changelog

read_current
[ "$VERSION" = "$NEW" ] && [ "$BUILD" = "$NEWBUILD" ] || die "bump did not apply cleanly; check git diff"
check_changelog
if [ -f "$LOG" ]; then
  echo "Updated project.pbxproj, project.yml, and CHANGELOG.md. Fill in the CHANGELOG entry, and put this line in the PR description:"
else
  echo "Updated project.pbxproj and project.yml. Put this line in the PR description:"
fi
echo "  Version bump: $OLD (build $OLDBUILD) to $NEW (build $NEWBUILD) ($RULE)"
echo "Tag hint: ${TAG_PREFIX}X.Y.Z (this version is ${TAG_PREFIX}$NEW)"
