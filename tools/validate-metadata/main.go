// Copyright 2026 The KubeAtlas Authors
// SPDX-License-Identifier: Apache-2.0

// Command validate-metadata is the offline lint for every pack's
// metadata.yaml. It loads the JSON Schema in metadata-schema.json
// (relative to the repo root) and validates each metadata.yaml the
// caller passes on the command line, exiting non-zero on the first
// failure so CI can pipe `find . -name metadata.yaml | xargs ...`.
//
// Usage:
//
//	validate-metadata <metadata.yaml> [<metadata.yaml> ...]
//	# or with no args: walks every <pack>/metadata.yaml in the cwd.
//
// The validator is a strict superset of what the KubeAtlas binary's
// loader checks at runtime (pkg/extractor/rego/loader.go validateMetadata).
// Anything this rejects, the binary will reject too — but the
// reverse is not guaranteed (kubeatlas-version semver constraints
// can only be checked once the binary version is known).
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/santhosh-tekuri/jsonschema/v5"
	"gopkg.in/yaml.v3"
)

const schemaPath = "metadata-schema.json"

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "validate-metadata:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	schema, err := loadSchema()
	if err != nil {
		return fmt.Errorf("load schema: %w", err)
	}

	targets := args
	if len(targets) == 0 {
		targets, err = discoverMetadata(".")
		if err != nil {
			return err
		}
		if len(targets) == 0 {
			fmt.Println("no metadata.yaml files found")
			return nil
		}
	}

	failed := 0
	for _, path := range targets {
		if err := validateOne(schema, path); err != nil {
			fmt.Fprintf(os.Stderr, "FAIL %s: %v\n", path, err)
			failed++
			continue
		}
		fmt.Printf("OK   %s\n", path)
	}
	if failed > 0 {
		return fmt.Errorf("%d file(s) failed validation", failed)
	}
	return nil
}

// loadSchema reads metadata-schema.json from a small set of likely
// locations: the repo root (when invoked from the project base) and
// the binary's own directory (when shipped alongside the tool).
func loadSchema() (*jsonschema.Schema, error) {
	candidates := []string{schemaPath, filepath.Join("..", "..", schemaPath)}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), schemaPath))
	}
	for _, p := range candidates {
		body, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		c := jsonschema.NewCompiler()
		if err := c.AddResource(p, bytes.NewReader(body)); err != nil {
			return nil, fmt.Errorf("compile schema %s: %w", p, err)
		}
		return c.Compile(p)
	}
	return nil, fmt.Errorf("metadata-schema.json not found in any of %v", candidates)
}

// discoverMetadata walks the current directory looking for every
// pack's metadata.yaml. Skips dot-dirs (.git, .github) so we do not
// surface tooling/config files as packs.
func discoverMetadata(root string) ([]string, error) {
	var out []string
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && len(d.Name()) > 0 && d.Name()[0] == '.' && path != root {
			return fs.SkipDir
		}
		if d.IsDir() && (d.Name() == "tools" || d.Name() == "samples" || d.Name() == "tests") {
			return fs.SkipDir
		}
		if !d.IsDir() && d.Name() == "metadata.yaml" {
			out = append(out, path)
		}
		return nil
	})
	return out, err
}

// validateOne reads one metadata.yaml, converts it to a JSON-shaped
// any (jsonschema validates against Go's encoding/json types), and
// runs the schema. Returns the first violation as a Go error.
func validateOne(schema *jsonschema.Schema, path string) error {
	body, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read: %w", err)
	}

	// yaml.v3 decodes YAML to map[string]any; jsonschema needs the
	// same shape encoding/json would emit, so route via JSON
	// round-trip to get json.Number / map[string]any consistently.
	var raw any
	if err := yaml.Unmarshal(body, &raw); err != nil {
		return fmt.Errorf("yaml parse: %w", err)
	}
	jsonBytes, err := json.Marshal(raw)
	if err != nil {
		return fmt.Errorf("re-encode as JSON: %w", err)
	}
	var doc any
	if err := json.Unmarshal(jsonBytes, &doc); err != nil {
		return fmt.Errorf("decode JSON: %w", err)
	}

	if err := schema.Validate(doc); err != nil {
		return err
	}
	return nil
}
