package contract

import "fmt"

type Graph struct {
	Services ServicesGraph
	Desktop  DesktopGraph
	Modes    ModesGraph
	Platform PlatformGraph
}

type ServicesGraph struct {
	OpenSSH        bool
	Autoupdate     bool
	Steam          bool
	Virtualisation bool
	Flatpak        bool
	Nixorcist      bool
	HomeManager    bool
	Copilot        bool
}

type DesktopGraph struct {
	Hyprland    bool
	KDE         bool
	Uwu         bool
	UwuPackages bool
}

type ModesGraph struct {
	GameOn bool
}

type PlatformGraph struct {
	KernelProfile string
	GPUProfile    string
}

type Features struct {
	KernelParams   string
	GPU            string
	OpenSSH        bool
	Autoupdate     bool
	Steam          bool
	Virtualisation bool
	Flatpak        bool
	Nixorcist      bool
	HomeManager    bool
	Copilot        bool
	Hyprland       bool
	KDE            bool
	Uwu            bool
	UwuPackages    bool
	GameOn         bool
}

func DeriveFeatures(g Graph) Features {
	return Features{
		KernelParams:   g.Platform.KernelProfile,
		GPU:            g.Platform.GPUProfile,
		OpenSSH:        g.Services.OpenSSH,
		Autoupdate:     g.Services.Autoupdate,
		Steam:          g.Services.Steam,
		Virtualisation: g.Services.Virtualisation,
		Flatpak:        g.Services.Flatpak,
		Nixorcist:      g.Services.Nixorcist,
		HomeManager:    g.Services.HomeManager,
		Copilot:        g.Services.Copilot,
		Hyprland:       g.Desktop.Hyprland,
		KDE:            g.Desktop.KDE,
		Uwu:            g.Desktop.Uwu,
		UwuPackages:    g.Desktop.UwuPackages,
		GameOn:         g.Modes.GameOn,
	}
}

func ValidateProfileCombo(kernelProfile, gpuProfile string) error {
	switch gpuProfile {
	case "none":
		return nil
	case "amd":
		if kernelProfile != "amd" {
			return fmt.Errorf(`gpu profile "amd" requires kernel profile "amd"`)
		}
	case "alurin":
		if kernelProfile != "alurin" {
			return fmt.Errorf(`gpu profile "alurin" requires kernel profile "alurin"`)
		}
	case "intel":
		if kernelProfile != "generic" && kernelProfile != "thinkpad" {
			return fmt.Errorf(`gpu profile "intel" requires kernel profile "generic" or "thinkpad"`)
		}
	case "nvidia", "nvidia-prime":
		if kernelProfile != "nvidia" {
			return fmt.Errorf(`gpu profile %q requires kernel profile "nvidia"`, gpuProfile)
		}
	default:
		return fmt.Errorf("unknown gpu profile %q", gpuProfile)
	}

	return nil
}
