#!/bin/bash

fancy_echo() {
	local fmt="$1"
	shift

	# shellcheck disable=SC2059
	printf "\\n$fmt\\n" "$@"
}

apple_m1() {
	sysctl -n machdep.cpu.brand_string | grep "Apple M1"
}

rosetta() {
	uname -m | grep "x86_64"
}

homebrew_installed_on_m1() {
	apple_m1 && ! rosetta && [ -d "/opt/homebrew" ]
}

homebrew_installed_on_intel() {
	! apple_m1 && command -v brew >/dev/null
}

install_or_update_homebrew() {
	if homebrew_installed_on_m1 || homebrew_installed_on_intel; then
		update_homebrew
	else
		install_homebrew
	fi
}

install_homebrew() {
	fancy_echo "Installing Homebrew ..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

update_homebrew() {
	fancy_echo "Homebrew already installed. Updating Homebrew ..."
	brew update
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e -o pipefail

fancy_echo 'Setting up your shiny new laptop...'

install_or_update_homebrew

fancy_echo "Verifying the Homebrew installation..."
if brew doctor; then
	fancy_echo "Your Homebrew installation is good to go."
else
	fancy_echo "Your Homebrew installation reported some errors or warnings."
	echo "Review the Homebrew messages to see if any action is needed."
fi

fancy_echo "Installing chezmoi and applying dotfiles ..."
brew bundle --file=- <<EOF
    brew 'chezmoi'
EOF

if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
	chezmoi init --apply --verbose https://github.com/allymparker/dotfiles.git
	chmod 0600 "$HOME/.config/chezmoi/chezmoi.toml"
fi

fancy_echo "Running your customizations from ~/.init ..."

if [ -f "$HOME/.Brewfile" ]; then
	fancy_echo "Installing tools and apps from .Brewfile..."
	if brew bundle --file="$HOME/.Brewfile"; then
		fancy_echo "All items in .Brewfile were installed successfully."
	else
		fancy_echo "Some items in .Brewfile were not installed successfully."
	fi
fi

fancy_echo "Configuring OMZ..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

fancy_echo "Configuring OMZ plugins..."
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

fancy_echo "Setting ZSH as default shell..."
if ! grep -Fxq $(command -v zsh) /etc/shells; then
	☸ production-admin
	command -v zsh | sudo tee -a /etc/shells
fi

if ! echo $SHELL | grep zsh; then
	chsh -s $(which zsh)
fi
