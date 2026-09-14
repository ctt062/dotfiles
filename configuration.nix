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
  # Globe+Q Quick Note makes the fn/globe key wait to see if Q follows.
  # Flip only that hotkey so other shortcuts stay untouched.
  #
  # Fn/globe language switch also waits on Slow Keys acceptance delay even
  # when Slow Keys is off. 0 is instant (Accessibility slider fully left).
  # Do not use system.defaults.CustomUserPreferences for
  # com.apple.universalaccess: `defaults write` is TCC-blocked and aborts
  # darwin-rebuild because the activate script runs with `set -e`.
  system.activationScripts.postActivation.text = ''
    plist="/Users/${user}/Library/Preferences/com.apple.symbolichotkeys.plist"
    if [ -f "$plist" ]; then
      sudo -u ${user} /usr/libexec/PlistBuddy -c 'Set :AppleSymbolicHotKeys:190:enabled false' "$plist" || true
    fi
    ua="/Users/${user}/Library/Preferences/com.apple.universalaccess.plist"
    if [ -f "$ua" ]; then
      sudo -u ${user} /usr/libexec/PlistBuddy -c 'Set :slowKeyDelay 0' "$ua" \
        || sudo -u ${user} /usr/libexec/PlistBuddy -c 'Add :slowKeyDelay integer 0' "$ua" \
        || true
    fi
  '';
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    # autoUpdate only refreshes formulae metadata; upgrade actually installs newer
    # versions. Without upgrade=true, brew bundle is invoked with --no-upgrade, so
    # claude-code / codex / etc. stay pinned at whatever was first installed.
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    onActivation.extraFlags = [ "--force" ];
    # Force cask upgrades even when Homebrew marks them auto-updating/unversioned.
    greedyCasks = true;
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
      "grok-build"
      "opensuperwhisper"
    ];
  };
}
