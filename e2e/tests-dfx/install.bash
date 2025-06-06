#!/usr/bin/env bats

load ../utils/_

setup() {
  standard_setup

  dfx_new_assets
}

teardown() {
  dfx_stop

  standard_teardown
}

@test "canister install --upgrade-unchanged upgrades even if the .wasm did not change" {
  dfx_start
  dfx canister create --all
  dfx build

  assert_command dfx canister install --all

  assert_command dfx canister install --all --mode upgrade
  assert_match "Module hash.*is already installed"

  assert_command dfx canister install --all --mode upgrade --upgrade-unchanged
  assert_not_match "Module hash.*is already installed"
}

@test "install fails if no argument is provided" {
  dfx_start
  assert_command_fail dfx canister install
  assert_match "required arguments were not provided"
  assert_match "--all"
}

@test "install succeeds when --all is provided" {
  dfx_start
  dfx canister create --all
  dfx build

  assert_command dfx canister install --all

  assert_match "Installed code for canister e2e_project_backend"
}

@test "install succeeds with network name" {
  dfx_start
  dfx canister create --all
  dfx build

  assert_command dfx canister install --all --network local

  assert_match "Installed code for canister e2e_project_backend"
}

@test "install fails with network name that is not in dfx.json" {
  dfx_start
  dfx canister create --all
  dfx build

  assert_command_fail dfx canister install --all --network nosuch

  assert_match "Network not found.*nosuch"
}

@test "install succeeds with arbitrary wasm" {
  dfx_start
  dfx canister create --all
  wallet="${archive:?}/wallet/0.10.0/wallet.wasm"
  assert_command dfx canister install e2e_project_backend --wasm "$wallet"
  assert_command dfx canister info e2e_project_backend
  assert_match "Module hash: 0x$(sha2sum "$wallet" | head -c 64)"
}

@test "install succeeds with canisterid" {
  dfx_start
  dfx canister create --all
  wallet="${archive:?}/wallet/0.10.0/wallet.wasm"
  CANISTER_ID=$(dfx canister id e2e_project_backend)
  assert_command dfx canister install "$CANISTER_ID" --wasm "$wallet"
  assert_command dfx canister info "$CANISTER_ID"
  assert_match "Module hash: 0x$(sha2sum "$wallet" | head -c 64)"
}

@test "install --all fails with arbitrary wasm" {
  dfx_start
  dfx canister create --all
  assert_command_fail dfx canister install --all --wasm "${archive:?}/wallet/0.10.0/wallet.wasm"
}

@test "install runs pre-post-install tasks" {
  install_asset pre_post_install
  dfx_start

  assert_command dfx canister create --all
  assert_command dfx build

  assert_command dfx canister install preinstall
  assert_match 'hello-pre-file'

  assert_command dfx canister install preinstall_script
  assert_match 'hello-pre-script'

  echo 'return 1' >> preinstall.sh
  assert_command_fail dfx canister install preinstall_script --mode upgrade
  assert_match 'hello-pre-script'

  assert_command dfx canister install postinstall
  assert_match 'hello-post-file'

  assert_command dfx canister install postinstall_script
  assert_match 'hello-post-script'

  echo 'return 1' >> postinstall.sh
  assert_command_fail dfx canister install postinstall_script --mode upgrade
  assert_match 'hello-post-script'
}

@test "pre-post-install tasks run in project root" {
  install_asset pre_post_install
  dfx_start

  assert_command dfx canister create --all
  assert_command dfx build

  cd src/e2e_project_backend

  assert_command dfx canister install preinstall_script
  assert_match 'hello-pre-script'
  assert_match "working directory of pre-install script: '.*/working-dir/e2e_project'"

  assert_command dfx canister install postinstall_script
  assert_match 'hello-post-script'
  assert_match "working directory of post-install script: '.*/working-dir/e2e_project'"
}

@test "pre-post-install tasks receive environment variables" {
  install_asset pre_post_install
  dfx_start
  echo "echo hello \$CANISTER_ID" >> preinstall.sh
  echo "echo hello \$CANISTER_ID" >> postinstall.sh

  assert_command dfx canister create --all
  assert_command dfx build
  id_pre=$(dfx canister id preinstall_script)
  id_post=$(dfx canister id postinstall_script)

  assert_command dfx canister install --all
  assert_match "hello $id_post"
  assert_command dfx canister install preinstall_script --mode upgrade
  assert_match "hello $id_pre"
  assert_command dfx canister install postinstall_script --mode upgrade
  assert_match "hello $id_post"

  assert_command dfx deploy
  assert_match "hello $id_post"
  assert_command dfx deploy preinstall_script
  assert_match "hello $id_pre"
  assert_command dfx deploy postinstall_script
  assert_match "hello $id_post"
}

@test "pre-post-install tasks discover dependencies" {
  install_asset pre_post_install
  dfx_start
  echo "echo hello \$CANISTER_ID_PREINSTALL" >> preinstall.sh
  echo "echo hello \$CANISTER_ID_POSTINSTALL" >> postinstall.sh

  assert_command dfx canister create --all
  assert_command dfx build
  id_pre=$(dfx canister id preinstall)
  id_post=$(dfx canister id postinstall)

  assert_command dfx canister install preinstall_script
  assert_match "hello $id_pre"

  assert_command dfx canister install postinstall_script
  assert_match "hello $id_post"
}

@test "can install gzip wasm" {
  jq '.canisters.e2e_project_backend.gzip=true' dfx.json | sponge dfx.json
  dfx_start
  dfx canister create --all
  assert_command dfx build
  assert_command dfx canister install --all
  BUILD_HASH="0x$(sha256sum .dfx/local/canisters/e2e_project_backend/e2e_project_backend.wasm.gz | cut -d " " -f 1)"
  ONCHAIN_HASH="$(dfx canister info e2e_project_backend | tail -n 1 | cut -d " " -f 3)"
  assert_eq "$BUILD_HASH" "$ONCHAIN_HASH"
}

@test "can install >2MiB wasm" {
  install_asset large_canister
  dfx_start
  dfx canister create --all
  assert_command dfx build
  assert_command dfx canister install --all
  assert_command dfx canister info large
  HASH="$(sha256sum .dfx/local/canisters/large/large.wasm | head -c 64)"
  assert_match "Module hash: 0x$HASH"
}

@test "can install large wasm with non-empty chunk store" {
  install_asset large_canister
  dfx_start
  dfx canister create --all
  CANISTER_ID=$(dfx canister id large)
  assert_command dfx canister call aaaaa-aa upload_chunk "(
  record {
    chunk = blob \"\\01\\02\";
    canister_id = principal \"$CANISTER_ID\";
  },
)"
  assert_command dfx build
  assert_command dfx canister install --all
  assert_command dfx canister info large
  HASH="$(sha256sum .dfx/local/canisters/large/large.wasm | head -c 64)"
  assert_match "Module hash: 0x$HASH"
}

@test "--mode=auto selects install or upgrade automatically" {
  dfx_start
  assert_command dfx canister create e2e_project_backend
  assert_command dfx build e2e_project_backend
  assert_command dfx canister install e2e_project_backend --mode auto
  assert_command dfx canister call e2e_project_backend greet dfx
  assert_command dfx canister install e2e_project_backend --mode auto --upgrade-unchanged
  assert_command dfx canister call e2e_project_backend greet dfx
}

@test "-y skips compat check" {
  dfx_start
  assert_command dfx canister create e2e_project_backend
  assert_command dfx build e2e_project_backend
  assert_command dfx canister install e2e_project_backend
  assert_command timeout -s9 20s dfx canister install e2e_project_backend --mode reinstall -y # if -y does not work, hangs without stdin
}

@test "--no-asset-upgrade skips asset upgrade" {
  dfx_start
  use_asset_wasm 0.12.1
  assert_command dfx deploy
  assert_command dfx canister info e2e_project_frontend
  assert_contains db07e7e24f6f8ddf53c33a610713259a7c1eb71c270b819ebd311e2d223267f0
  use_default_asset_wasm
  assert_command dfx build e2e_project_frontend # otherwise the new wasm is not picked up
  assert_command dfx canister install e2e_project_frontend --mode upgrade --no-asset-upgrade
  assert_command dfx canister info e2e_project_frontend
  assert_contains db07e7e24f6f8ddf53c33a610713259a7c1eb71c270b819ebd311e2d223267f0
}

@test "installing one canister with an argument succeeds" {
  dfx_start
  assert_command dfx canister create e2e_project_backend
  assert_command dfx build e2e_project_backend
  assert_command dfx canister install e2e_project_backend --argument '()'
}

@test "installing one canister specifying raw argument succeeds" {
  dfx_start
  assert_command dfx canister create e2e_project_backend
  assert_command dfx build e2e_project_backend
  assert_command dfx canister install e2e_project_backend --argument '4449444c0000' --argument-type raw
}

@test "installing with an argument in a file succeeds" {
  dfx_start
  assert_command dfx canister create e2e_project_backend
  assert_command dfx build e2e_project_backend
  TMPFILE="$(mktemp)"
  echo '()' >"$TMPFILE"
  assert_command dfx canister install e2e_project_backend --argument-file "$TMPFILE"
}

@test "installing with an argument on stdin succeeds" {
  dfx_start
  assert_command dfx canister create e2e_project_backend
  assert_command dfx build e2e_project_backend
  TMPFILE="$(mktemp)"
  echo '()' >"$TMPFILE"
  assert_command dfx canister install e2e_project_backend --argument-file - <"$TMPFILE"
}

@test "installing multiple canisters with arguments fails" {
  assert_command_fail dfx canister install --all --argument '()'
  assert_contains "error: the argument '--all' cannot be used with '--argument <ARGUMENT>'"
}

@test "remind to build before install" {
  dfx_start
  dfx canister create --all
  assert_command_fail dfx canister install e2e_project_backend
  assert_contains "The canister must be built before install. Please run \`dfx build\`."
}

@test "install succeeds if init_arg is defined in dfx.json" {
  install_asset deploy_deps
  dfx_start
  jq '.canisters.dependency.init_arg="(\"dfx\")"' dfx.json | sponge dfx.json

  dfx canister create dependency
  dfx build dependency
  assert_command dfx canister install dependency
  assert_command dfx canister call dependency greet
  assert_match "Hello, dfx!"

  assert_command dfx canister install dependency --mode reinstall --yes --argument '("icp")'
  assert_contains "Canister 'dependency' has init_arg/init_arg_file in dfx.json: (\"dfx\"),"
  assert_contains "which is different from the one specified in the command line: (\"icp\")."
  assert_contains "The command line value will be used."
  assert_command dfx canister call dependency greet
  assert_match "Hello, icp!"
}

@test "install succeeds if init_arg_file is defined in dfx.json" {
  install_asset deploy_deps
  dfx_start
  mkdir arg-files
  echo '("dfx")' >> arg-files/args.txt
  jq '.canisters.dependency.init_arg_file="arg-files/args.txt"' dfx.json | sponge dfx.json

  dfx canister create dependency
  dfx build dependency

  # The following commands will be run in this sub-directory, it verifies that the init_arg_file is relative to the dfx.json file
  cd arg-files
  assert_command dfx canister install dependency
  assert_command dfx canister call dependency greet
  assert_match "Hello, dfx!"
}

@test "install fails if both init_arg and init_arg_file are defined in dfx.json" {
  install_asset deploy_deps
  dfx_start
  echo '("dfx")' >> args.txt
  jq '.canisters.dependency.init_arg="(\"dfx\")"' dfx.json | sponge dfx.json
  jq '.canisters.dependency.init_arg_file="args.txt"' dfx.json | sponge dfx.json

  dfx canister create dependency
  dfx build dependency
  assert_command_fail dfx canister install dependency
  assert_contains "At most one of the fields 'init_arg' and 'init_arg_file' should be defined in \`dfx.json\`.
Please remove one of them or leave both undefined."
}

@test "install succeeds when specify canister id and wasm, in dir without dfx.json" {
  dfx_start

  dfx canister create --all
  CANISTER_ID=$(dfx canister id e2e_project_backend)
  dfx build
  rm dfx.json
  assert_command dfx canister install "$CANISTER_ID" --wasm .dfx/local/canisters/e2e_project_backend/e2e_project_backend.wasm
}

@test "repeated install wasm" {
  install_asset custom_canister
  install_asset wasm/identity
  dfx_start
  dfx deploy
  for _ in {1..50}
  do
  echo yes | dfx canister install --mode=reinstall custom
  done
}

@test "specify upgrade options (skip_pre_upgrade, wasm_memory_persistence)" {
  dfx_start
  dfx canister create e2e_project_backend
  dfx build e2e_project_backend

  # The canister is not installed yet and the mode is 'auto'.
  # The actual InstallMode will be 'install'.
  # In this case, the provided upgrade options are just hint which doesn't take effect.
  assert_command dfx canister install e2e_project_backend --mode auto --skip-pre-upgrade

  assert_command dfx canister install e2e_project_backend --mode auto --wasm-memory-persistence keep
  assert_command dfx canister install e2e_project_backend --mode auto --wasm-memory-persistence replace
  assert_command dfx canister install e2e_project_backend --mode auto --skip-pre-upgrade --wasm-memory-persistence keep

  assert_command dfx canister install e2e_project_backend --mode upgrade --skip-pre-upgrade
  assert_command dfx canister install e2e_project_backend --mode upgrade --wasm-memory-persistence keep
  assert_command dfx canister install e2e_project_backend --mode upgrade --wasm-memory-persistence replace
  assert_command dfx canister install e2e_project_backend --mode upgrade --skip-pre-upgrade --wasm-memory-persistence keep

  assert_command_fail dfx canister install e2e_project_backend --mode install --skip-pre-upgrade
  assert_contains "--skip-pre-upgrade and --wasm-memory-persistence can only be used with mode 'upgrade' or 'auto'."
  assert_command_fail dfx canister install e2e_project_backend --mode reinstall --wasm-memory-persistence keep
  assert_contains "--skip-pre-upgrade and --wasm-memory-persistence can only be used with mode 'upgrade' or 'auto'."
}

@test "Candid UI" {
  dfx_start
  dfx deploy
  ID=$(dfx canister id __Candid_UI)
  PORT=$(get_webserver_port)
  assert_command curl http://localhost:"$PORT"/?canisterId="$ID"
  assert_match "Candid UI"
}
