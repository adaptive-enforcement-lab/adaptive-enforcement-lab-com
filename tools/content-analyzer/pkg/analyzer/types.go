package analyzer

// Result contains all analysis metrics for a single file.
type Result struct {
	File        string      `json:"file"`
	Structural  Structural  `json:"structural"`
	Headings    Headings    `json:"headings"`
	Readability Readability `json:"readability"`
	Composition Composition `json:"composition"`
	Status      string      `json:"status"`
}

// Structural contains basic document metrics.
type Structural struct {
	Lines              int `json:"lines"`
	Words              int `json:"words"`
	Sentences          int `json:"sentences"`
	Characters         int `json:"characters"`
	ReadingTimeMinutes int `json:"reading_time_minutes"`
}

// Headings contains heading counts by level.
type Headings struct {
	H1 int `json:"h1"`
	H2 int `json:"h2"`
	H3 int `json:"h3"`
	H4 int `json:"h4"`
	H5 int `json:"h5"`
	H6 int `json:"h6"`
}

// Readability contains all readability scores.
type Readability struct {
	FleschKincaidGrade float64 `json:"flesch_kincaid_grade"`
	FleschReadingEase  float64 `json:"flesch_reading_ease"`
	ARI                float64 `json:"ari"`
	ColemanLiau        float64 `json:"coleman_liau"`
	GunningFog         float64 `json:"gunning_fog"`
	SMOG               float64 `json:"smog"`
}

// Composition contains content type breakdown.
type Composition struct {
	TotalLines     int     `json:"total_lines"`
	ProseLines     int     `json:"prose_lines"`
	CodeLines      int     `json:"code_lines"`
	EmptyLines     int     `json:"empty_lines"`
	CodeBlockRatio float64 `json:"code_block_ratio"`
}

// Thresholds defines limits for pass/fail checks.
// Deprecated: Use config.Thresholds instead.
type Thresholds struct {
	MaxFleschKincaidGrade float64
	MaxARI                float64
	MaxGunningFog         float64
	MinFleschReadingEase  float64
	MaxLines              int
}

// DefaultThresholds returns sensible defaults for technical documentation.
// Deprecated: Use config.DefaultConfig instead.
func DefaultThresholds() Thresholds {
	return Thresholds{
		MaxFleschKincaidGrade: 16.0, // College senior level
		MaxARI:                16.0,
		MaxGunningFog:         18.0,
		MinFleschReadingEase:  25.0,
		MaxLines:              375,
	}
}
