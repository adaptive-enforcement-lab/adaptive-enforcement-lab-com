# Readability Formulas

## Formula Comparison

| Formula | Input Variables | Output | Best For | Limitations |
|---------|-----------------|--------|----------|-------------|
| **Flesch-Kincaid Grade** | Words, sentences, syllables | US grade level | General content | Syllable counting complexity |
| **Flesch Reading Ease** | Words, sentences, syllables | 0-100 score | Quick assessment | Not grade-aligned |
| **Gunning Fog** | Words, sentences, complex words | Years of education | Business/professional | Overestimates technical docs |
| **SMOG** | Polysyllabic words, sentences | Years of education | Healthcare/safety | Requires 30+ sentences |
| **Coleman-Liau** | Characters, words, sentences | US grade level (1-12) | Technical docs | Capped at grade 12 |
| **ARI** | Characters, words, sentences | US grade level | Machine analysis | Character-based only |

## Formula Definitions

### Flesch-Kincaid Grade Level

```
FK = 0.39 × (words/sentences) + 11.8 × (syllables/words) − 15.59
```

Interpretation: US grade level required to understand the text.

### Flesch Reading Ease

```
FRE = 206.835 − 1.015 × (words/sentences) − 84.6 × (syllables/words)
```

| Score | Difficulty | Audience |
|-------|------------|----------|
| 90-100 | Very Easy | 5th grade |
| 80-89 | Easy | 6th grade |
| 70-79 | Fairly Easy | 7th grade |
| 60-69 | Standard | 8th-9th grade |
| 50-59 | Fairly Difficult | 10th-12th grade |
| 30-49 | Difficult | College |
| 0-29 | Very Difficult | College graduate |

### Automated Readability Index (ARI)

```
ARI = 4.71 × (characters/words) + 0.5 × (words/sentences) − 21.43
```

Advantage: Character-based counting is deterministic (no syllable ambiguity).

### Coleman-Liau Index

```
CLI = 0.0588 × L − 0.296 × S − 15.8
```

Where:

- `L` = average letters per 100 words
- `S` = average sentences per 100 words

Advantage: Designed for technical documents, character-based.

### Gunning Fog Index

```
Fog = 0.4 × ((words/sentences) + 100 × (complex_words/words))
```

Where `complex_words` = words with 3+ syllables (excluding proper nouns, compounds,
common suffixes).

### SMOG Index

```
SMOG = 1.0430 × √(polysyllables × (30/sentences)) + 3.1291
```

Where `polysyllables` = words with 3+ syllables in a 30-sentence sample.

## Industry Benchmarks

| Source | Target Grade Level | Notes |
|--------|-------------------|-------|
| Microsoft Style Guide | 8-10 | "Clean, simple, crisp and clear" |
| Google Developer Docs | 8-10 | "Conversational, friendly" |
| US Government (Plain Language Act) | 6-8 | Legal requirement for public docs |
| MIL-STD-38784 | 8-10 | Military technical manuals |

## References

- [Flesch-Kincaid Readability Tests](https://en.wikipedia.org/wiki/Flesch–Kincaid_readability_tests)
- [Automated Readability Index](https://en.wikipedia.org/wiki/Automated_readability_index)
- [Google Developer Style Guide](https://developers.google.com/style/)
- [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/)
