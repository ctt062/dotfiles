{ config, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # Activation PATH is minimal and defaults to macOS bash 3.2 + BSD userland.
  # Home Manager needs bash >= 4.2 (`[[ -v ]]`), GNU readlink -e, and GNU find
  # -printf. Also ship tools that downstream install scripts call by bare name.
  extraToolsPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.curl
    pkgs.git
    pkgs.gnutar
    pkgs.gzip
    pkgs.unzip
  ];
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  # Same Determinate Nix options.json warning as nix-darwin docs; manpages
  # default on and rebuild options.json on every switch.
  manual.manpages.enable = false;
  manual.html.enable = false;
  manual.json.enable = false;

  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    # the font everything renders in
    nerd-fonts.hack
    unzip
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";
  
  # no-mistakes / treehouse land binaries here; Cursor CLI uses it too.
  # home.sessionPath alone is not enough on macOS: /etc/zprofile's path_helper
  # rebuilds PATH after ~/.zshenv and drops $HOME/.local/bin for login shells.
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Tools that are not clean Homebrew/Nix packages (curl installers, npm globals, git clone).
  # Homebrew packages from configuration.nix are available by the time this runs on switch.
  # Re-run installers / pulls on every switch so these stay current alongside brew upgrades.
  home.activation = {
    # Must run before checkLinkTargets/linkGeneration so GNU readlink -e works.
    ensureActivationPath = config.lib.dag.entryBefore [ "checkFilesChanged" ] ''
      export PATH="${extraToolsPath}:/opt/homebrew/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"
    '';

    installExtraTools = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.local/bin"

      echo "Updating no-mistakes..."
      # Install script ends with `daemon restart`, which can fail outside a
      # no-mistakes repo (gate_context). Treat the binary as the success signal.
      curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh || true
      if [ ! -x "$HOME/.no-mistakes/bin/no-mistakes" ]; then
        echo "error: no-mistakes missing after install" >&2
        exit 1
      fi
      ln -sfn "$HOME/.no-mistakes/bin/no-mistakes" "$HOME/.local/bin/no-mistakes"

      echo "Syncing no-mistakes agent preference (Grok, Cursor, Claude, Codex, OpenCode, Pi)..."
      bash "${dotfiles}/home/scripts/sync-no-mistakes-config.sh"

      echo "Updating treehouse..."
      curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh || true
      if [ ! -x "$HOME/.local/bin/treehouse" ]; then
        echo "error: treehouse install finished but $HOME/.local/bin/treehouse is missing" >&2
        exit 1
      fi

      if command -v npm >/dev/null 2>&1; then
        echo "Updating pi..."
        # Official install uses --ignore-scripts; pi does not need lifecycle scripts.
        npm install -g --ignore-scripts @earendil-works/pi-coding-agent
        if ! command -v pi >/dev/null 2>&1; then
          echo "error: pi missing after install" >&2
          exit 1
        fi

        # Install AXI CLIs + skills and link them into Claude/Codex/Cursor/opencode/Grok.
        bash "${dotfiles}/home/scripts/sync-axi-skills.sh"
      else
        echo "error: npm not on PATH yet (Homebrew node); cannot install pi / sync AXI skills" >&2
        exit 1
      fi

      if [ -d "$HOME/firstmate/.git" ]; then
        echo "Updating firstmate..."
        git -C "$HOME/firstmate" pull --ff-only || true
      else
        echo "Cloning firstmate into ~/firstmate..."
        git clone https://github.com/kunchenguid/firstmate "$HOME/firstmate"
      fi
    '';
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    # profileExtra runs after macOS path_helper in login shells.
    profileExtra = ''
      path=("$HOME/.local/bin" $path)
      # Keep the Python.org 3.11 framework install on PATH when present.
      if [ -d /Library/Frameworks/Python.framework/Versions/3.11/bin ]; then
        path=("/Library/Frameworks/Python.framework/Versions/3.11/bin" $path)
      fi
    '';
    initContent = ''
      path=("$HOME/.local/bin" $path)
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      gs = "git status";
      gc = "git commit -m";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude";
      co = "codex";
      ca = "cursor-agent";
      gk = "grok";
      # Overrides macOS /usr/bin/nm (symbol dumper) in interactive zsh.
      nm = "no-mistakes";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "ctt062";
      email = "chongtt062@gmail.com";
    };
    # Global hooks so agent Co-authored-by trailers are stripped in every repo.
    # The commit-msg hook chains to each repo's .git/hooks/commit-msg when present.
    settings.core.hooksPath = "${config.home.homeDirectory}/.config/git/hooks";
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/git/hooks" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/git/hooks";
    force = true;
  };
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  # Grok Build loads global rules from ~/.grok/ (AGENTS.md family).
  home.file.".grok/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  # Cursor does not treat ~/.cursor/AGENTS.md as a documented global rules source.
  # Keep the symlink as the live file agents are told to Read, and also install a
  # local Cursor plugin with an alwaysApply rule so every Agent chat gets it.
  home.file.".cursor/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".cursor/plugins/local/global-agents".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.cursor/plugins/global-agents";

  # Keep the Cursor alwaysApply snapshot aligned with home/AGENTS.md on every switch.
  home.activation.syncCursorGlobalAgentsRule =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.python3}/bin/python3 \
        "${dotfiles}/home/.cursor/plugins/global-agents/sync-rule.py" \
        "${dotfiles}/home/AGENTS.md" \
        "${dotfiles}/home/.cursor/plugins/global-agents/rules/global-agent-instructions.mdc"
    '';

  # Re-apply Cursor CLI/IDE attribution-off so rebuild keeps Co-authored-by trailers disabled.
  home.activation.syncCursorAttribution =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      bash "${dotfiles}/home/scripts/sync-cursor-attribution.sh"
    '';
}
