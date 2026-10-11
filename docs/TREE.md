# Tree Structure of the Repository

```txt
.
├── AGENTS.md
├── default
│   └── rig-skill
│       └── SKILL.md
├── docs
│   ├── TREE.md
│   └── vanguard.md
├── .github
│   └── workflows
│       └── ci.yml
├── .gitignore
├── LICENSE
├── README.md
├── tests
│   ├── common
│   │   ├── dotfiles-repo.test.sh
│   │   ├── helpers.test.sh
│   │   ├── libexec.test.sh
│   │   ├── syntax.test.sh
│   │   └── test-packages.test.sh
│   ├── fedora
│   │   ├── dispatcher.test.sh
│   │   ├── dotfiles.test.sh
│   │   ├── helpers.test.sh
│   │   ├── pkg.test.sh
│   │   ├── reset.test.sh
│   │   └── syntax.test.sh
│   ├── macos
│   │   ├── dispatcher.test.sh
│   │   ├── helpers.test.sh
│   │   ├── pkg.test.sh
│   │   ├── reset.test.sh
│   │   └── syntax.test.sh
│   ├── run.sh
│   └── test_helper.sh
├── unix
│   ├── common
│   │   ├── config
│   │   │   ├── git.sh
│   │   │   ├── nextdns.sh
│   │   │   └── rust.sh
│   │   ├── dotfiles
│   │   │   ├── directories.sh
│   │   │   ├── fonts.sh
│   │   │   ├── ghostty.sh
│   │   │   ├── stow.sh
│   │   │   └── zsh.sh
│   │   ├── helpers
│   │   │   ├── common.sh
│   │   │   ├── logging.sh
│   │   │   ├── packages.sh
│   │   │   └── platform.sh
│   │   ├── install
│   │   │   └── external
│   │   │       └── skillset.sh
│   │   └── libexec
│   │       ├── rig-drift
│   │       ├── rig-fonts
│   │       ├── rig-install
│   │       ├── rig-install-skillset
│   │       ├── rig-llama
│   │       ├── rig-llama-proxy
│   │       ├── rig-ocr
│   │       ├── rig-pkg-add
│   │       ├── rig-pkg-list
│   │       ├── rig-pkg-remove
│   │       ├── rig-pkg-search
│   │       ├── rig-reset
│   │       └── rig-stow
│   ├── fedora
│   │   ├── bin
│   │   │   └── rig
│   │   ├── config.json
│   │   ├── fedora-setup
│   │   ├── health-check.sh
│   │   ├── install
│   │   │   ├── config
│   │   │   │   ├── all.sh
│   │   │   │   ├── appimage.sh
│   │   │   │   ├── firmware.sh
│   │   │   │   ├── git.sh
│   │   │   │   ├── hardware
│   │   │   │   │   ├── all.sh
│   │   │   │   │   ├── asus
│   │   │   │   │   │   ├── audio.sh
│   │   │   │   │   │   ├── base.sh
│   │   │   │   │   │   ├── bin
│   │   │   │   │   │   │   └── asus-profile-notify
│   │   │   │   │   │   ├── power.sh
│   │   │   │   │   │   ├── sleep.sh
│   │   │   │   │   │   └── system-sleep
│   │   │   │   │   │       ├── force-igpu
│   │   │   │   │   │       └── unmount-fuse
│   │   │   │   │   ├── asus.sh
│   │   │   │   │   └── nvidia.sh
│   │   │   │   ├── hibernation.sh
│   │   │   │   ├── kde
│   │   │   │   │   ├── kdeglobals
│   │   │   │   │   ├── kglobalshortcutsrc
│   │   │   │   │   ├── kwinrc
│   │   │   │   │   ├── kwinrulesrc
│   │   │   │   │   └── plasmaparc
│   │   │   │   ├── kde.sh
│   │   │   │   ├── keepass.sh
│   │   │   │   ├── multimedia.sh
│   │   │   │   ├── nextdns.sh
│   │   │   │   ├── performance.sh
│   │   │   │   ├── secureboot.sh
│   │   │   │   ├── services.sh
│   │   │   │   └── system.sh
│   │   │   ├── dotfiles
│   │   │   │   ├── all.sh
│   │   │   │   ├── directories.sh
│   │   │   │   ├── fonts.sh
│   │   │   │   ├── stow.sh
│   │   │   │   └── zsh.sh
│   │   │   ├── external
│   │   │   │   └── all.sh
│   │   │   ├── helpers
│   │   │   │   ├── all.sh
│   │   │   │   ├── common.sh
│   │   │   │   ├── logging.sh
│   │   │   │   └── presentation.sh
│   │   │   ├── packaging
│   │   │   │   ├── all.sh
│   │   │   │   ├── base.sh
│   │   │   │   ├── bloatware.sh
│   │   │   │   ├── flatpak.sh
│   │   │   │   ├── npm.sh
│   │   │   │   ├── rofimoji.sh
│   │   │   │   ├── rust.sh
│   │   │   │   └── webapps.sh
│   │   │   ├── post-install
│   │   │   │   ├── all.sh
│   │   │   │   └── finished.sh
│   │   │   ├── preflight
│   │   │   │   ├── all.sh
│   │   │   │   ├── guard.sh
│   │   │   │   └── show-env.sh
│   │   │   └── repositories
│   │   │       ├── all.sh
│   │   │       ├── copr.sh
│   │   │       ├── external.sh
│   │   │       ├── rpmfusion.sh
│   │   │       └── terra.sh
│   │   ├── libexec
│   │   │   ├── rig-launch-webapp
│   │   │   ├── rig-migrate
│   │   │   ├── rig-webapp-install
│   │   │   └── rig-webapp-remove
│   │   ├── migrations
│   │   │   ├── 1760447549.sh
│   │   │   ├── 1760448059.sh
│   │   │   ├── 1760448554.sh
│   │   │   ├── 1760458816.sh
│   │   │   ├── 1760553421.sh
│   │   │   ├── 1760633726.sh
│   │   │   ├── 1760812842.sh
│   │   │   ├── 1760989194.sh
│   │   │   ├── 1761961692.sh
│   │   │   ├── 1786219610.sh
│   │   │   ├── 1787250762.sh
│   │   │   └── migration-generate
│   │   ├── packages
│   │   │   ├── base.packages
│   │   │   ├── bloatware.packages
│   │   │   ├── development.packages
│   │   │   ├── flatpak.packages
│   │   │   ├── npm.packages
│   │   │   ├── rust.packages
│   │   │   ├── system.packages
│   │   │   └── tools.packages
│   │   └── README.md
│   ├── macos
│   │   ├── bin
│   │   │   └── rig
│   │   ├── config.json
│   │   ├── install
│   │   │   ├── config
│   │   │   │   ├── all.sh
│   │   │   │   ├── git.sh
│   │   │   │   ├── nextdns.sh
│   │   │   │   └── system.sh
│   │   │   ├── dotfiles
│   │   │   │   ├── all.sh
│   │   │   │   ├── directories.sh
│   │   │   │   ├── fonts.sh
│   │   │   │   ├── stow.sh
│   │   │   │   └── zsh.sh
│   │   │   ├── external
│   │   │   │   └── all.sh
│   │   │   ├── helpers
│   │   │   │   ├── all.sh
│   │   │   │   ├── common.sh
│   │   │   │   └── logging.sh
│   │   │   ├── packaging
│   │   │   │   ├── all.sh
│   │   │   │   ├── brew.sh
│   │   │   │   ├── cask.sh
│   │   │   │   ├── homebrew.sh
│   │   │   │   └── rust.sh
│   │   │   ├── post-install
│   │   │   │   ├── all.sh
│   │   │   │   └── finished.sh
│   │   │   └── preflight
│   │   │       ├── all.sh
│   │   │       └── guard.sh
│   │   ├── macos-setup
│   │   ├── packages
│   │   │   ├── brew.packages
│   │   │   ├── cask.packages
│   │   │   └── rust.packages
│   │   └── README.md
│   └── setup
└── windows
    ├── powershell
    │   ├── gp_backup.ps1
    │   ├── Microsoft.PowerShell_profile.ps1
    │   ├── modules
    │   │   ├── vanguard.ps1
    │   │   └── vanguard_scheduler.ps1
    │   └── setup.ps1
    ├── pro_scripts
    │   ├── bypassnro.bat
    │   ├── ms-account-check.bat
    │   ├── policies-enabler.ps1
    │   ├── reset-windows-update-component.bat
    │   └── wufix.bat
    ├── registry_edits
    │   ├── device-guard
    │   │   ├── down.reg
    │   │   └── up.reg
    │   └── folders-to-ThisPC
    │       ├── down.reg
    │       └── up.reg
    ├── theme
    │   └── pix-dynamc-theme.deskthemepack
    └── tools
        ├── ofgb
        │   └── placeholder
        └── winutil
            ├── build.ps1
            ├── windows.ico
            ├── winutil.exe
            └── winutil.ps1

59 directories, 187 files
```

tree generated with `tree -a -I ".git|fonts|themes|lua|__pycache__|*.jpg|*.png|*.webp|*.jpeg|*.gif|.DS_Store" .`
