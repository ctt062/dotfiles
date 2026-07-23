{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  # Skip nix-darwin's documentation module entirely. Its `let` binding always
  # evaluates options.json even when documentation.enable = false, and Determinate
  # Nix warns about that derivation's missing store-path context (upstream:
  # home-manager#7935 / nixpkgs make-options-doc). Package man pages from brew
  # and nixpkgs are unaffected.
  disabledModules = [ "documentation" ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
      "gnhf"
      "node"
      "gh"
      "tmux"
      "opencode"
    ];
    casks = [
      "wezterm"
      "claude-code"
      "cursor-cli"
      "codex"
      "opensuperwhisper"
    ];
  };
}
