{ lib
, buildGoModule
, fetchFromGitHub
, protobuf_26
, git
, testers
, buf
, installShellFiles
}:

buildGoModule rec {
  pname = "buf";
  version = "1.45.0";

  src = fetchFromGitHub {
    owner = "bufbuild";
    repo = "buf";
    rev = "v${version}";
    hash = "sha256-zmk9o0P4BaUqng9E/s6KKWntwS4NmTg/xPTrQruTQSo=";
  };

  vendorHash = "sha256-NMrPBUwbDsXW8tc5l1Liqd19+v2RrXf6dlcwVnHxVXQ=";

  patches = [
    # Skip a test that requires networking to be available to work.
    ./skip_broken_tests.patch
  ];

  nativeBuildInputs = [ installShellFiles ];

  ldflags = [ "-s" "-w" ];

  nativeCheckInputs = [
    git # Required for TestGitCloner
    protobuf_26 # Required for buftesting.GetProtocFilePaths
  ];

  checkFlags = [
    "-skip=TestWorkspaceGit"
  ];

  preCheck = ''
    # For WebAssembly runtime tests
    GOOS=wasip1 GOARCH=wasm go build -o $GOPATH/bin/buf-plugin-suffix.wasm \
      ./private/bufpkg/bufcheck/internal/cmd/buf-plugin-suffix

    # The tests need access to some of the built utilities
    export PATH="$PATH:$GOPATH/bin"
  '';

  # Allow tests that bind or connect to localhost on macOS.
  __darwinAllowLocalNetworking = true;

  installPhase = ''
    runHook preInstall

    # Binaries
    # Only install required binaries, don't install testing binaries
    for FILE in buf protoc-gen-buf-breaking protoc-gen-buf-lint; do
      install -D -m 555 -t $out/bin $GOPATH/bin/$FILE
    done

    # Completions
    installShellCompletion --cmd buf \
      --bash <($GOPATH/bin/buf completion bash) \
      --fish <($GOPATH/bin/buf completion fish) \
      --zsh <($GOPATH/bin/buf completion zsh)

    # Man Pages
    mkdir man && $GOPATH/bin/buf manpages man
    installManPage man/*

    runHook postInstall
  '';

  passthru.tests.version = testers.testVersion { package = buf; };

  meta = with lib; {
    homepage = "https://buf.build";
    changelog = "https://github.com/bufbuild/buf/releases/tag/v${version}";
    description = "Create consistent Protobuf APIs that preserve compatibility and comply with design best-practices";
    license = licenses.asl20;
    maintainers = with maintainers; [ jk lrewega aaronjheng ];
    mainProgram = "buf";
  };
}
