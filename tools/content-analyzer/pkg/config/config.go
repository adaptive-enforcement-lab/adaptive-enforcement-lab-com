package config

import (
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Config represents the content analyzer configuration.
type Config struct {
	Thresholds Thresholds          `yaml:"thresholds"`
	Overrides  []PathOverride      `yaml:"overrides,omitempty"`
}

// Thresholds defines limits for pass/fail checks.
type Thresholds struct {
	MaxGrade  float64 `yaml:"max_grade"`
	MaxARI    float64 `yaml:"max_ari"`
	MaxFog    float64 `yaml:"max_fog"`
	MinEase   float64 `yaml:"min_ease"`
	MaxLines  int     `yaml:"max_lines"`
	MinWords  int     `yaml:"min_words"`  // Skip readability checks if below this
}

// PathOverride allows different thresholds for specific paths.
type PathOverride struct {
	Path       string     `yaml:"path"`
	Thresholds Thresholds `yaml:"thresholds"`
}

// DefaultConfig returns sensible defaults for technical documentation.
func DefaultConfig() *Config {
	return &Config{
		Thresholds: Thresholds{
			MaxGrade: 16.0,  // College senior
			MaxARI:   16.0,
			MaxFog:   18.0,
			MinEase:  25.0,
			MaxLines: 375,
			MinWords: 100,   // Skip readability for very short/code-heavy docs
		},
	}
}

// Load reads configuration from a YAML file.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	cfg := DefaultConfig()
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	return cfg, nil
}

// LoadOrDefault tries to load config from path, returns default if not found.
func LoadOrDefault(path string) *Config {
	cfg, err := Load(path)
	if err != nil {
		return DefaultConfig()
	}
	return cfg
}

// FindConfigFile searches for .content-analyzer.yml in the given directory
// and parent directories up to the git root.
func FindConfigFile(startDir string) string {
	dir := startDir
	for {
		configPath := filepath.Join(dir, ".content-analyzer.yml")
		if _, err := os.Stat(configPath); err == nil {
			return configPath
		}

		// Check for git root (stop searching)
		gitDir := filepath.Join(dir, ".git")
		if _, err := os.Stat(gitDir); err == nil {
			// We're at git root, check one more time then stop
			configPath := filepath.Join(dir, ".content-analyzer.yml")
			if _, err := os.Stat(configPath); err == nil {
				return configPath
			}
			return ""
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			// Reached filesystem root
			return ""
		}
		dir = parent
	}
}

// ThresholdsForPath returns the appropriate thresholds for a given file path.
func (c *Config) ThresholdsForPath(filePath string) Thresholds {
	// Normalize path separators and strip relative prefixes
	normalizedPath := filepath.ToSlash(filePath)

	// Strip leading ../ sequences (for when running from subdirectory)
	for strings.HasPrefix(normalizedPath, "../") {
		normalizedPath = normalizedPath[3:]
	}
	// Strip leading ./
	normalizedPath = strings.TrimPrefix(normalizedPath, "./")

	// Check overrides in order (first match wins)
	for _, override := range c.Overrides {
		overridePath := filepath.ToSlash(override.Path)
		if strings.HasPrefix(normalizedPath, overridePath) {
			// Merge with defaults - override only specified values
			return mergeThresholds(c.Thresholds, override.Thresholds)
		}
	}

	return c.Thresholds
}

// mergeThresholds returns base thresholds with non-zero override values applied.
// Note: MinEase uses != 0 to allow negative values (for disabling the check).
func mergeThresholds(base, override Thresholds) Thresholds {
	result := base
	if override.MaxGrade > 0 {
		result.MaxGrade = override.MaxGrade
	}
	if override.MaxARI > 0 {
		result.MaxARI = override.MaxARI
	}
	if override.MaxFog > 0 {
		result.MaxFog = override.MaxFog
	}
	if override.MinEase != 0 {
		result.MinEase = override.MinEase
	}
	if override.MaxLines > 0 {
		result.MaxLines = override.MaxLines
	}
	if override.MinWords > 0 {
		result.MinWords = override.MinWords
	}
	return result
}
