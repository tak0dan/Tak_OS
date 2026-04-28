package contract

import "testing"

func TestDeriveFeaturesFromGraph(t *testing.T) {
	g := Graph{
		Services: ServicesGraph{
			OpenSSH:        true,
			Autoupdate:     true,
			Steam:          true,
			Virtualisation: true,
			Flatpak:        true,
			Nixorcist:      false,
			HomeManager:    true,
			Copilot:        true,
		},
		Desktop: DesktopGraph{
			Hyprland:    true,
			KDE:         true,
			Uwu:         true,
			UwuPackages: false,
		},
		Modes: ModesGraph{
			GameOn: false,
		},
		Platform: PlatformGraph{
			KernelProfile: "thinkpad",
			GPUProfile:    "none",
		},
	}

	got := DeriveFeatures(g)

	if got.KernelParams != "thinkpad" || got.GPU != "none" {
		t.Fatalf("unexpected platform derivation: %+v", got)
	}

	if !got.OpenSSH || !got.Autoupdate || !got.Steam || !got.Virtualisation || !got.Flatpak || !got.HomeManager || !got.Copilot {
		t.Fatalf("expected enabled graph services to normalize into enabled features: %+v", got)
	}

	if got.Nixorcist || got.UwuPackages || got.GameOn {
		t.Fatalf("expected disabled graph nodes to stay disabled: %+v", got)
	}
}

func TestValidateProfileComboAccepted(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name   string
		kernel string
		gpu    string
	}{
		{name: "headless", kernel: "thinkpad", gpu: "none"},
		{name: "thinkpad-intel", kernel: "thinkpad", gpu: "intel"},
		{name: "generic-intel", kernel: "generic", gpu: "intel"},
		{name: "amd-stack", kernel: "amd", gpu: "amd"},
		{name: "alurin-stack", kernel: "alurin", gpu: "alurin"},
		{name: "nvidia-stack", kernel: "nvidia", gpu: "nvidia"},
		{name: "nvidia-prime-stack", kernel: "nvidia", gpu: "nvidia-prime"},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if err := ValidateProfileCombo(tc.kernel, tc.gpu); err != nil {
				t.Fatalf("expected %s/%s to be valid, got %v", tc.kernel, tc.gpu, err)
			}
		})
	}
}

func TestValidateProfileComboRejected(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name   string
		kernel string
		gpu    string
	}{
		{name: "amd-on-thinkpad", kernel: "thinkpad", gpu: "amd"},
		{name: "alurin-on-amd", kernel: "amd", gpu: "alurin"},
		{name: "nvidia-on-thinkpad", kernel: "thinkpad", gpu: "nvidia"},
		{name: "nvidia-prime-on-generic", kernel: "generic", gpu: "nvidia-prime"},
		{name: "intel-on-amd-kernel", kernel: "amd", gpu: "intel"},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if err := ValidateProfileCombo(tc.kernel, tc.gpu); err == nil {
				t.Fatalf("expected %s/%s to be rejected", tc.kernel, tc.gpu)
			}
		})
	}
}
