# Heading 1

## Heading 2 with [link](https://example.com)

### Heading 3

#### Heading 4

##### Heading 5

###### Heading 6

Normal text with **bold** and *italic* and ~~strikethrough~~.

Underscore bold: __double underscore__ and italic: _single underscore_.

`inline code with **not bold**`

More text with `code` inside.

Multi-backtick: `` `**` `` and ``` ``code`` ```.

```bash
echo "code block"
```

~~~python
print("tilde code block")
~~~

Nested code block (tilde wrapping backticks):

~~~markdown
Here is how to write a code block:

```bash
echo "Hello"
```
~~~

Four-space indented fence becomes content (CommonMark rule):

```markdown
- List item with code block:

    ```bash
    echo "indented code"
    ```
```

> blockquote with **bold** text

> nested > quote

---

***

[simple link](https://example.com)

![image alt](https://example.com/img.png)

[![linked image](https://example.com/img.png)](https://example.com)

<!-- HTML comment -->

<!--
multi-line comment
-->

## Heading with [link](https://example.com) inside

**bold with `code` inside**

Escaped: \**not bold\** and \`not code\`

Word boundaries: abc_def_ghi and foo__bar__baz and x___y___z.

## Table Example

|Name|Description|Status|
|-|-|-|
|greple|Pattern matching tool|active|
|ansifold|ANSI-aware text folding|active|
|ansicolumn|Column formatting with ANSI support|active|

## Aligned Table

| Left | Center | Right | Default |
|:-----|:------:|------:|---------|
| a    | b      | c     | d       |
| long | x      | y     | z       |

## List Example

- First item with `inline code`
- Second item with **bold text** and _italic_
- Third item with a longer description that might wrap to multiple lines when displayed in a narrow terminal window

## Definition List Example

greple
: Pattern matching and highlighting tool with extensive regex support for syntax highlighting

ansifold
: ANSI-aware text folding utility that wraps long lines while preserving escape sequences and maintaining proper indentation

Term with blank line

: Definition after a blank line with `inline code` and **bold text** that might wrap to multiple lines
