package output

import (
	"encoding/json"
	"io"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/analyzer"
)

// JSON writes results as JSON.
func JSON(w io.Writer, results []*analyzer.Result) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")

	if len(results) == 1 {
		return encoder.Encode(results[0])
	}

	return encoder.Encode(results)
}
