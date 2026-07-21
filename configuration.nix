{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

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
    ];
    casks = [
      "wezterm"
      "claude-code"
      "cursor-cli"
      "codex"
    ];
  };
 
  # for opencode
  system.activationScripts = {
    opencode = {
      text = ''
        echo "=== Running post-activation scripts ==="

        # Ensure unzip is available
        if ! command -v unzip >/dev/null 2>&1; then
          echo "Installing unzip via Nix..."
          /nix/var/nix/profiles/default/bin/nix-env -iA nixpkgs.unzip
        fi

        # Install Opencode if not present
        if ! command -v opencode >/dev/null 2>&1; then
          echo "Installing Opencode..."
          curl -fsSL https://opencode.ai/install | bash
        else
          echo "Opencode already installed."
        fi
      '';
    };
  };
}
