{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
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
  home.activation = {
    installExtraTools = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.git}/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"
      curl=${pkgs.curl}/bin/curl
      git=${pkgs.git}/bin/git
      mkdir -p "$HOME/.local/bin"

      # Prefer the real install locations over command -v (PATH is unreliable here).
      if [ ! -x "$HOME/.local/bin/no-mistakes" ] && [ ! -x "$HOME/.no-mistakes/bin/no-mistakes" ]; then
        echo "Installing no-mistakes..."
        "$curl" -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
      fi
      if [ -x "$HOME/.no-mistakes/bin/no-mistakes" ] && [ ! -e "$HOME/.local/bin/no-mistakes" ]; then
        ln -sfn "$HOME/.no-mistakes/bin/no-mistakes" "$HOME/.local/bin/no-mistakes"
      fi

      if [ ! -x "$HOME/.local/bin/treehouse" ]; then
        echo "Installing treehouse..."
        "$curl" -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
      fi
      if [ ! -x "$HOME/.local/bin/treehouse" ]; then
        echo "error: treehouse install finished but $HOME/.local/bin/treehouse is missing" >&2
        exit 1
      fi

      if command -v npm >/dev/null 2>&1; then
        echo "Ensuring gh-axi and lavish-axi are installed globally..."
        npm install -g gh-axi lavish-axi
        # PromptScript has no global skills dir; target agents that do.
        npx --yes skills add kunchenguid/gh-axi --skill gh-axi -y -g \
          --agent claude-code cursor codex opencode || true
        npx --yes skills add kunchenguid/lavish-axi --skill lavish -y -g \
          --agent claude-code cursor codex opencode || true
      else
        echo "npm not on PATH yet (Homebrew node); skip gh-axi/lavish-axi until next rebuild."
      fi

      if [ ! -d "$HOME/firstmate/.git" ]; then
        echo "Cloning firstmate into ~/firstmate..."
        "$git" clone https://github.com/kunchenguid/firstmate "$HOME/firstmate"
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
    '';
    initContent = ''
      path=("$HOME/.local/bin" $path)
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude";
      co = "codex";
      ca = "cursor-agent";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "ctt062";
      email = "chongtt062@gmail.com";
    };
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
  home.file.".cursor/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
