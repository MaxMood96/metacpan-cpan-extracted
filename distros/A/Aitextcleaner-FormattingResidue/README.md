# aitextcleaner-formatting-residue

`aitextcleaner-formatting-residue` is a lightweight, deterministic Python library designed to clean common artifacts left behind when copying text from web pages, document editors, or generated text exports. It operates entirely locally with no external dependencies or network requests.

## What It Does

- Strips basic copied HTML block tags and markup wrappers.
- Normalizes typographic punctuation residue (such as stray formatting quotes and dashes).
- Collapses repeated blank lines and removes trailing whitespace.

## What It Does Not Do

- It does not detect AI-generated writing or analyze text semantics.
- It does not guarantee originality, bypass detection tools, or rewrite content.
- It only applies deterministic formatting cleanup to the string provided.

## Python API Usage

The library exposes a single function: `clean_formatting_residue(text: str)`.

```python
from aitextcleaner_formatting_residue import clean_formatting_residue

raw_text = "<div><p>Sample text with trailing spaces.   \n\n\n\nNext line.</p></div>"
cleaned = clean_formatting_residue(raw_text)
print(cleaned)
```

## Command-Line Interface

The CLI reads from standard input or an optional positional UTF-8 file argument and outputs the cleaned result directly to standard output:

```bash
# Read from a file argument
aitextcleaner-formatting-residue input.txt

# Read from standard input
cat input.txt | aitextcleaner-formatting-residue
```

All processing occurs offline in memory; no network calls are made.

## Testing

You can run the test suite locally using `pytest`:

```bash
pytest
```

## Related Resources & Metadata

For additional context on text cleanup patterns and web tools, visit the [AI Text Cleaner web utility](https://aitextcleaner.pro/). Package metadata and repository links may also point to this project homepage.

## License

This project is distributed under the MIT License.
