# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.3] - 2026-02-23

### Added

- Icons column in directory listing using Font Awesome 6 (CDN).
- New `icons` parameter on `WebServer::DirIndex` (defaults to true) to enable
  or disable the icon column.
- New `icon` parameter on `WebServer::DirIndex::File` holding the explicit
  Font Awesome CSS class string for the entry's icon.
- New `icons` parameter on `WebServer::DirIndex::File` (defaults to false);
  when true, the icon is automatically derived from `mime_type` using a
  built-in mapping; an explicitly supplied `icon` value always takes precedence.
- New `file_html_icons` and `dir_html_icons` templates in
  `WebServer::DirIndex::HTML` for icon-aware rendering.
- Icon mapping in `WebServer::DirIndex::File` covers: directories, parent
  directory, plain text, HTML/CSS/JS/JSON/XML (code), CSV, PDF, Word, Excel,
  PowerPoint, images, audio, video, archives (zip/tar/gz/bz2/rar),
  with a generic file icon as the fallback.
- `.icon` CSS rule added to both standard and pretty stylesheets in
  `WebServer::DirIndex::CSS`.

## [0.0.2] - 2026-02-22

### Changed

- Replaced `Plack::MIME` with `MIME::Types` for MIME type lookups.
- Replaced `Plack::Util::encode_html` with `HTML::Escape::escape_html` from the
  `HTML::Escape` module, removing the dependency on `Plack` entirely.
- Converted `sub file_html` and `sub dir_html` in `WebServer::DirIndex::HTML` from class
  methods (subs) to fields with `:reader`, making them instance-level read accessors.
- Converted `sub standard_css` and `sub pretty_css` in `WebServer::DirIndex::CSS` from
  plain subs to fields with `:reader`, making them instance-level read accessors.
- Updated callers in `WebServer::DirIndex`, `WebServer::DirIndex::File`, and tests to
  use `->new->method` instead of `->method` for `WebServer::DirIndex::HTML`.
- Moved `render()` method from `WebServer::DirIndex::HTML` to `WebServer::DirIndex::to_html`.
- Added `to_html()` method to `WebServer::DirIndex::File` that renders a single
  file entry as an HTML table row (with all fields HTML-escaped). The `render()`
  method in `WebServer::DirIndex` now delegates to this method per file.

### Added

- New `WebServer::DirIndex::File` class to encapsulate directory entry data (url, name, size, mime_type, mtime).

### Fixed

- Correct copyright date.

## [0.0.1] - 2026-02-21

### Added

- Initial release of `WebServer::DirIndex`, `WebServer::DirIndex::HTML`, and `WebServer::DirIndex::CSS`.

[Unreleased]: https://github.com/davorg-cpan/webserver-dirindex/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/davorg-cpan/webserver-dirindex/releases/tag/v0.0.1
