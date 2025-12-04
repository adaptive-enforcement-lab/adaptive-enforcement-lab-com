package markdown

import (
	"bytes"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/text"
)

// ParseResult contains extracted content from a markdown file.
type ParseResult struct {
	Prose      string
	CodeBlocks []string
	Headings   []Heading
	TotalLines int
	CodeLines  int
	EmptyLines int
}

// Heading represents a markdown heading.
type Heading struct {
	Level int
	Text  string
}

// Parse extracts prose content, code blocks, and headings from markdown.
func Parse(content []byte) (*ParseResult, error) {
	md := goldmark.New()
	reader := text.NewReader(content)
	doc := md.Parser().Parse(reader)

	result := &ParseResult{
		CodeBlocks: make([]string, 0),
		Headings:   make([]Heading, 0),
	}

	var proseBuilder strings.Builder

	// Walk the AST to extract content
	ast.Walk(doc, func(node ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}

		switch n := node.(type) {
		case *ast.Heading:
			heading := Heading{
				Level: n.Level,
				Text:  string(n.Text(content)),
			}
			result.Headings = append(result.Headings, heading)

		case *ast.FencedCodeBlock:
			var codeContent bytes.Buffer
			lines := n.Lines()
			for i := 0; i < lines.Len(); i++ {
				line := lines.At(i)
				codeContent.Write(line.Value(content))
			}
			result.CodeBlocks = append(result.CodeBlocks, codeContent.String())

		case *ast.CodeBlock:
			var codeContent bytes.Buffer
			lines := n.Lines()
			for i := 0; i < lines.Len(); i++ {
				line := lines.At(i)
				codeContent.Write(line.Value(content))
			}
			result.CodeBlocks = append(result.CodeBlocks, codeContent.String())

		case *ast.Text:
			// Only extract text that's not inside code blocks
			parent := n.Parent()
			if !isInsideCodeBlock(parent) {
				proseBuilder.Write(n.Segment.Value(content))
				if n.HardLineBreak() || n.SoftLineBreak() {
					proseBuilder.WriteString(" ")
				} else {
					proseBuilder.WriteString(" ")
				}
			}

		case *ast.String:
			parent := n.Parent()
			if !isInsideCodeBlock(parent) {
				proseBuilder.Write(n.Value)
				proseBuilder.WriteString(" ")
			}
		}

		return ast.WalkContinue, nil
	})

	result.Prose = strings.TrimSpace(proseBuilder.String())

	// Count lines
	lines := bytes.Split(content, []byte("\n"))
	result.TotalLines = len(lines)

	// Count code lines and empty lines
	inCodeBlock := false
	for _, line := range lines {
		trimmed := bytes.TrimSpace(line)
		if bytes.HasPrefix(trimmed, []byte("```")) {
			inCodeBlock = !inCodeBlock
			result.CodeLines++
			continue
		}
		if inCodeBlock {
			result.CodeLines++
		} else if len(trimmed) == 0 {
			result.EmptyLines++
		}
	}

	return result, nil
}

// isInsideCodeBlock checks if a node is inside a code block.
func isInsideCodeBlock(node ast.Node) bool {
	for node != nil {
		switch node.(type) {
		case *ast.FencedCodeBlock, *ast.CodeBlock, *ast.CodeSpan:
			return true
		}
		node = node.Parent()
	}
	return false
}
