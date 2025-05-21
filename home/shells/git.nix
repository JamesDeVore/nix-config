# /my-nix-config/home/tools/git.nix
{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "jdevore";
    userEmail = "jdevore4592@gmail.com";
    # signing = {
    #   key = "your-gpg-key-id"; # Optional GPG signing
    #   signByDefault = true;
    # };
    extraConfig = {
      init.defaultBranch = "main";
      # github.user = "your-github-username"; # Useful for some hub/gh commands
      credential.helper = "${pkgs.gitFull}/bin/git-credential-libsecret"; # For GNOME Keyring or KDE Wallet
      # Or for caching:
      # credential.helper = "cache --timeout=3600";
    };
  };

  # Lazygit
  programs.lazygit = {
    enable = true;
    # Optional: if you need specific settings, though lazygit is mostly self-contained
    # settings = {
    #   gui = {
    #     # ...
    #   };
    # };
  };
}
