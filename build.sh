#!/usr/bin/env bash

set -euo pipefail

# mapfile needs bash 4; the system /bin/bash is 3.2.
if ((BASH_VERSINFO[0] < 4)); then
  printf 'bash 4 or later is required (found %s).\n' "$BASH_VERSION" >&2
  exit 1
fi

# Paths below are relative to the repository root.
cd "$(dirname "$0")"

start_time="$(date +%s)"

elapsed_time() {
  local elapsed=$(($(date +%s) - start_time))
  printf '%dm %ds' "$((elapsed / 60))" "$((elapsed % 60))"
}

path_exists() { [[ -e "$1" || -L "$1" ]]; }

codesign_identity="${EMACS_CODESIGN_IDENTITY:-Emacs}"

codesign_identity_available_p() {
  [[ "$codesign_identity" == "-" ]] && return 0

  security find-identity -v -p codesigning 2>/dev/null |
    grep -F "\"$codesign_identity\"" >/dev/null
}

sign_emacs_app() {
  local app="$1"
  local libexec="$app/Contents/MacOS/libexec"
  local resource_libexec="$app/Contents/Resources/libexec"

  if path_exists "$resource_libexec"; then
    printf 'Refusing to replace existing bundle path: %s\n' "$resource_libexec" >&2
    return 1
  fi
  mv "$libexec" "$resource_libexec"
  ln -s ../Resources/libexec "$libexec"

  codesign --force --sign "$codesign_identity" "$app/Contents/MacOS/Emacs.sh"
  # UserNotifications rejects the linker's ad-hoc "temacs-<hash>"
  # identifier, silently suppressing notifications.
  codesign --force --sign "$codesign_identity" --identifier org.gnu.Emacs "$app"
  codesign --verify --deep --strict "$app"
}

apply_liquid_glass_icon() {
  local app="$1"
  local plist="$app/Contents/Info.plist"

  # The bundle is copied from the build directory; a VPATH build does
  # not copy the alternate icon, and dropping Emacs.icns anyway would
  # leave the bundle without an icon.
  [[ -f "$app/Contents/Resources/EmacsLG1-Default.icns" ]] || {
    printf 'EmacsLG1-Default.icns is missing from %s.\n' "$app" >&2
    return 1
  }
  rm -f "$app/Contents/Resources/Emacs.icns"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile EmacsLG1-Default.icns' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string EmacsLG1' "$plist"
}

configure_fingerprint_file=".build-configure-fingerprint"

configure_args() {
  local brew_prefix
  # Command substitution does not inherit set -e, so the failure has to
  # be propagated by hand; a caller that read an empty brew_prefix would
  # configure against /include and /lib.
  brew_prefix="$(brew --prefix)" || return 1

  printf '%s\n' \
    --enable-gcc-warnings=yes \
    --enable-mac-app=yes \
    --enable-mac-self-contained \
    --with-native-compilation \
    --with-tree-sitter \
    "CC=ccache clang" \
    "CPPFLAGS=-I${brew_prefix}/include" \
    "CFLAGS=-O2 -pipe -mcpu=native -fobjc-arc -fno-omit-frame-pointer" \
    "LDFLAGS=-L${brew_prefix}/lib -Wl,-dead_strip"
}

# Run brew rather than just look for it: configure_args reads its
# output, and every caller of configure_args must fail before it can
# act on a misconfiguration.
require_configure_tools() {
  brew --prefix >/dev/null 2>&1 || {
    printf 'A working brew is required to locate include and lib paths\n' >&2
    exit 1
  }
  command -v ccache >/dev/null 2>&1 || {
    printf 'ccache is required; install it with: brew install ccache\n' >&2
    exit 1
  }
}

run_configure() {
  require_configure_tools

  # mapfile from a process substitution would take an empty array for
  # success and run ./configure with no arguments at all.  The command
  # substitution gives set -e the status, and the declaration is
  # separate because local would mask it.
  local args_text
  args_text="$(configure_args)"
  local -a args
  mapfile -t args <<<"$args_text"

  [[ -x ./configure ]] || ./autogen.sh
  ./configure "${args[@]}"
  printf '%s\n' "$args_text" >"$configure_fingerprint_file"
}

ensure_configured() {
  require_configure_tools

  if [[ ! -x ./config.status ]]; then
    printf 'No config.status; running one-time autogen and configure.\n' >&2
    run_configure
    return
  fi

  if configure_args | cmp -s - "$configure_fingerprint_file" 2>/dev/null; then
    return
  fi

  printf 'Configure flags changed; discarding compiled objects and reconfiguring.\n' >&2
  # Discard before reconfiguring: run_configure records the new
  # fingerprint on its way out, and a fingerprint recorded while stale
  # objects survive an interrupted clean would skip the discard for
  # good.  The Makefiles track no dependency on the flags.
  gmake -C lib clean
  gmake -C lib-src clean
  gmake -C src clean
  run_configure
}

macro_fingerprint_file=".build-macro-fingerprint"

# Macro and inline-function expansions are compiled into every caller,
# and the Makefiles track no such dependency, so edits to their sources
# leave stale expansions in unchanged .elc files.  Generated files
# (loaddefs.el, cus-load.el) carry copied macro forms and change on
# every scrape, so only sources git does not ignore are fingerprinted.
macro_fingerprint() {
  { git ls-files -coz --exclude-standard -- 'lisp/*.el' |
      xargs -0 grep -slE \
        '^\((defmacro|cl-defmacro|defsubst|cl-defsubst|cl-defstruct|define-inline) ' ||
      true; } |
    tr '\n' '\0' | LC_ALL=C sort -z | xargs -0 shasum -a 256 2>/dev/null |
    shasum -a 256 | cut -d' ' -f1
}

reset_lisp_on_macro_change() {
  local current recorded=none
  current="$(macro_fingerprint)"
  [[ -f "$macro_fingerprint_file" ]] && recorded="$(<"$macro_fingerprint_file")"
  if [[ "$current" == "$recorded" ]]; then
    return
  fi

  if [[ "$recorded" == none ]]; then
    printf 'No macro fingerprint; discarding compiled Lisp to flush stale expansions.\n' >&2
  else
    printf 'Macro-bearing sources changed; discarding compiled Lisp to flush stale expansions.\n' >&2
  fi
  rm -rf native-lisp
  find lisp -name '*.elc' -delete
  find lisp -name '*loaddefs.el' ! -name '.*' -delete
  gmake -C lib clean
  gmake -C lib-src clean
  # Leftover emacs and bootstrap-emacs dumps reference the deleted .eln
  # files by hash and cannot start; src clean removes them, and ccache
  # keeps the C rebuild cheap.
  gmake -C src clean
  printf '%s\n' "$current" >"$macro_fingerprint_file"
}

build_emacs() { gmake -j "$(($(sysctl -n hw.ncpu) + 1))"; }

preloaded_native_p() {
  "${1:-./src/emacs}" --batch -Q --eval \
    '(kill-emacs (if (subr-native-elisp-p (symbol-function (quote find-file))) 0 1))'
}

dump_records_install_path_p() {
  grep -aqF "../Frameworks/native-lisp/" src/emacs.pdmp
}

output_dir="${EMACS_OUTPUT_DIR:-$PWD/out}"
# The value becomes DESTDIR, which a recursive make resolves against
# each subdirectory, and git_clean_reset strips $PWD from it to see
# whether it lies inside the tree.  Both need an absolute path in
# normal form.  The directory need not exist yet, so normalize
# lexically; `..' is left alone because resolving it would have to
# follow symlinks.
[[ "$output_dir" == /* ]] || output_dir="$PWD/$output_dir"
while [[ "$output_dir" == *//* || "$output_dir" == */./* ]]; do
  output_dir="${output_dir//\/\//\/}"
  output_dir="${output_dir//\/.\//\/}"
done
output_dir="${output_dir%/.}"
[[ "$output_dir" == / ]] || output_dir="${output_dir%/}"

output_app="$output_dir/Emacs.app"
install_stamp="$output_dir/.build-stamp"
staging_root=""
install_committed=no
pruned_any=no
prune_warnings=()

# Record prune warnings for a final repeat; gmake install scrolls them away.
note_prune_warning() {
  prune_warnings+=("$1")
  printf '%s\n' "$1" >&2
}

# A deleted source keeps its autoloads registered in the generated
# loaddefs files, where they stay callable; removing a stale file makes
# the build regenerate it from the surviving sources.
prune_stale_loaddefs() {
  local loaddefs dir src stale pruned_stale=no
  while IFS= read -r loaddefs; do
    dir="${loaddefs%/*}"
    stale=""
    while IFS= read -r src; do
      if [[ ! -f "$dir/$src" ]]; then
        stale="$src"
        break
      fi
    done < <(sed -n 's/^;;; Generated autoloads from //p' "$loaddefs")
    [[ -n "$stale" ]] || continue
    printf 'Pruned stale %s (%s is gone)\n' "$loaddefs" "$stale" >&2
    rm -f "$loaddefs" "${loaddefs%.el}.elc"
    pruned_stale=yes
    pruned_any=yes
  done < <(find lisp -name '*loaddefs.el' ! -name '.*')

  # While lisp/loaddefs.el exists, regeneration only rescrapes sources
  # newer than it, so a pruned subdirectory loaddefs whose sources are
  # all old would never be rebuilt; drop it to force a full rescrape.
  if [[ "$pruned_stale" == yes ]]; then
    rm -f lisp/loaddefs.el lisp/loaddefs.elc
  fi
}

# Orphan .elc files (source deleted) ship in Emacs.app and stay requirable:
# load prefers .elc over .el.  Object files need no such care.
prune_orphan_elc() {
  local elc el
  while IFS= read -r elc; do
    el="${elc%.elc}.el"
    [[ -f "$el" || -f "$el.gz" ]] && continue
    rm -f "$elc"
    pruned_any=yes
    printf 'Pruned orphan %s\n' "$elc" >&2
  done < <(find lisp -name '*.elc')
}

# Superseded native-lisp/<version>-<hash> directories linger and get
# installed.  The dump embeds the hash it loads; keep exactly those.
prune_stale_eln_dirs() {
  [[ -d native-lisp && -f src/emacs.pdmp ]] || return 0

  local -a keep=() drop=()
  local dir name
  for dir in native-lisp/*/; do
    [[ -d "$dir" ]] || continue
    name="${dir#native-lisp/}"
    name="${name%/}"
    if grep -qaF "$name" src/emacs.pdmp; then
      keep+=("$dir")
    else
      drop+=("$dir")
    fi
  done

  if ((${#keep[@]} == 0)); then
    note_prune_warning 'No native-lisp directory matches the dump; left the cache alone.'
    return 0
  fi

  for dir in "${drop[@]}"; do
    printf 'Pruning stale native-lisp directory %s\n' "$dir" >&2
    rm -rf "$dir"
    pruned_any=yes
  done
}

# An .eln is named for its source's path and contents, both hashed, so only
# the Emacs just built can enumerate the live set; drop whatever the cache
# holds beyond it.  Base names cover the preloaded/ subdirectory too.
prune_orphan_eln() {
  [[ -x src/emacs && -d native-lisp ]] || return 0

  local work path
  work="$(mktemp -d)"

  find native-lisp -name '*.eln' >"$work/paths"
  if [[ ! -s "$work/paths" ]]; then
    rm -rf "$work"
    return 0
  fi

  if ! ./src/emacs --batch -Q --eval \
    '(dolist (f (directory-files-recursively "lisp" "\\.el$"))
       (princ (comp-el-to-eln-rel-filename f))
       (terpri))' >"$work/expected" 2>/dev/null ||
    [[ ! -s "$work/expected" ]]; then
    note_prune_warning 'Could not enumerate expected .eln names; left the cache alone.'
    rm -rf "$work"
    return 0
  fi

  sort -u "$work/expected" -o "$work/expected"
  sed 's|.*/||' "$work/paths" | sort -u >"$work/present"
  comm -23 "$work/present" "$work/expected" >"$work/orphans"

  # "Every .eln is an orphan" means the enumeration itself is wrong; bail.
  if cmp -s "$work/present" "$work/orphans"; then
    note_prune_warning 'No .eln matches the enumeration; left the cache alone.'
    rm -rf "$work"
    return 0
  fi

  awk 'NR == FNR { orphan[$0]; next }
       { name = $0; sub(/.*\//, "", name); if (name in orphan) print }' \
    "$work/orphans" "$work/paths" >"$work/delete"

  while IFS= read -r path; do
    printf 'Pruning orphan %s\n' "$path" >&2
    rm -f "$path"
    pruned_any=yes
  done <"$work/delete"

  rm -rf "$work"
}

# The paths gmake install copies into Emacs.app; shared by both freshness
# checks so they agree on the input set.
installable_input_paths() {
  local p
  for p in build.sh mac/Emacs.app src/emacs src/emacs.pdmp lisp etc info \
    leim native-lisp lib-src doc/man; do
    path_exists "$p" && printf '%s\n' "$p"
  done
}

# Catches what the mtime check cannot: input files added or removed, and
# edited install rules (Makefile.in contents).
install_fingerprint() {
  local -a inputs
  mapfile -t inputs < <(installable_input_paths)
  {
    find "${inputs[@]}" -type f -print 2>/dev/null | LC_ALL=C sort
    printf 'rules\n'
    git ls-files -z -- '*Makefile.in' 2>/dev/null | LC_ALL=C sort -z |
      xargs -0 shasum -a 256 2>/dev/null
  } | shasum -a 256 | cut -d' ' -f1
}

# Skip staging/install/sign when nothing changed; gmake install is not
# incremental.  The stamp holds the signing identity (line 1) and the
# fingerprint (line 2); its mtime is the freshness baseline.
install_up_to_date_p() {
  # Pruning only deletes, so it never bumps a file past the stamp.
  [[ "$pruned_any" == no ]] || return 1
  path_exists "$output_app" || return 1
  [[ -f "$install_stamp" ]] || return 1

  local stamp_identity stamp_fingerprint
  {
    read -r stamp_identity
    read -r stamp_fingerprint
  } <"$install_stamp" 2>/dev/null
  [[ "$stamp_identity" == "$codesign_identity" ]] || return 1
  [[ "$stamp_fingerprint" == "$(install_fingerprint)" ]] || return 1

  local -a inputs
  mapfile -t inputs < <(installable_input_paths)

  # Regular files only: temp-and-rename rewrites bump directory mtimes
  # without changing content.
  [[ -z "$(find "${inputs[@]}" -type f -newer "$install_stamp" -print 2>/dev/null | head -n1)" ]]
}

cleanup_install() {
  local status=$?

  trap - EXIT HUP INT TERM
  set +e

  if [[ "$install_committed" != yes && -n "$staging_root" ]]; then
    rm -rf "$staging_root"
  fi

  if path_exists "$staging_root"; then
    printf 'Cleanup is incomplete; inspect %s\n' "$staging_root" >&2
  fi

  exit "$status"
}

# Remove everything git does not track except the protected paths.
git_clean_reset() {
  local protected='^\.claude(/|$)'
  # The output directory is protected only when it lies inside the tree.
  local output_rel="${output_dir#"$PWD"/}"
  local -a targets=()
  local path answer
  # core.quotePath=false keeps non-ASCII paths unquoted; paths with
  # control characters or double quotes are still quoted and are not
  # handled here.
  while IFS= read -r path; do
    [[ "$path" =~ $protected ]] && continue
    [[ "$output_rel" != "$output_dir" ]] \
      && [[ "$path" == "$output_rel" || "$path" == "$output_rel"/* ]] \
      && continue
    targets+=("./$path")
  done < <(LC_ALL=C git -c core.quotePath=false clean -ndx \
             | sed -n 's/^Would remove //p')

  if ((${#targets[@]} == 0)); then
    printf 'Nothing to remove.\n' >&2
    return
  fi

  printf '%s\n' "${targets[@]}"
  read -r -p "Remove the ${#targets[@]} paths above? (yes/no) " answer
  if [[ "$answer" != yes ]]; then
    printf 'Aborted; nothing was removed.\n' >&2
    exit 1
  fi
  rm -rf "${targets[@]}"
}

# Checked before the init branch, which also ends with a notification.
command -v n >/dev/null 2>&1 || {
  printf 'The notification helper (n) is required to report completion.\n' >&2
  exit 1
}

if [[ "${1:-}" == "init" ]]; then
  git_clean_reset
  run_configure
  printf '\nemacs-mac init completed in %s\n' "$(elapsed_time)"
  n --message "emacs-mac init"
  exit
fi

command -v gmake >/dev/null 2>&1 || {
  printf 'GNU Make (gmake) is required; the Makefiles use 3.82+ syntax.\n' >&2
  exit 1
}
codesign_identity_available_p || {
  printf 'No valid code-signing identity matches EMACS_CODESIGN_IDENTITY.\n' >&2
  printf 'Create it in the login keychain, or set EMACS_CODESIGN_IDENTITY=- for ad-hoc signing.\n' >&2
  exit 1
}

ensure_configured

reset_lisp_on_macro_change

prune_stale_loaddefs
prune_orphan_elc
build_emacs

if ! preloaded_native_p; then
  printf 'Preloaded Lisp is not native; rebuilding from a clean native-lisp.\n' >&2
  rm -rf native-lisp src/emacs.pdmp
  build_emacs

  preloaded_native_p || {
    printf 'Preloaded Lisp is still not native after a clean rebuild.\n' >&2
    exit 1
  }
fi

if ! dump_records_install_path_p; then
  printf 'The dump lacks installed native-lisp paths; redumping.\n' >&2
  rm -f src/emacs.pdmp
  build_emacs

  dump_records_install_path_p || {
    printf 'The dump still lacks installed native-lisp paths after redumping.\n' >&2
    exit 1
  }
fi

# After the final dump: the pdmp says which cache is live.
prune_stale_eln_dirs
prune_orphan_eln

mkdir -p "$output_dir"

if install_up_to_date_p; then
  printf 'No installable input changed; reusing the existing Emacs.app.\n' >&2
else
  staging_root="$(mktemp -d "$output_dir/.Emacs.install.XXXXXX")"
  staged_app="$staging_root/Applications/Emacs.app"
  trap cleanup_install EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  gmake DESTDIR="$staging_root" install

  # Drop the Linux systemd unit install-etc leaves behind; must precede
  # signing.
  rm -rf "$staged_app/Contents/Resources/lib/systemd"

  apply_liquid_glass_icon "$staged_app"
  sign_emacs_app "$staged_app"

  preloaded_native_p "$staged_app/Contents/MacOS/Emacs" || {
    printf 'The staged Emacs.app failed to start with native preloaded Lisp.\n' >&2
    exit 1
  }

  rm -f "$install_stamp"
  rm -rf "$output_app"
  mv "$staged_app" "$output_app"
  install_committed=yes

  rm -rf "$staging_root"
  staging_root=""
  trap - EXIT HUP INT TERM

  {
    printf '%s\n' "$codesign_identity"
    install_fingerprint
  } >"$install_stamp"
fi

printf '\nSync:\n  rsync -avX --delete %q /Applications/Emacs.app/\n' "$output_app/"
printf '\nTotal build time: %s\n' "$(elapsed_time)"

if ((${#prune_warnings[@]} > 0)); then
  printf '\nStale artifacts may have shipped in Emacs.app:\n' >&2
  printf '  %s\n' "${prune_warnings[@]}" >&2
  printf 'Run "%s init" for a full reset.\n' "$0" >&2
  n --message "emacs-mac built at $output_app (pruning skipped)"
else
  n --message "emacs-mac built at $output_app"
fi
