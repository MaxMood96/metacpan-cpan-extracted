# DEVELOPMENT

We use `Minilla` as our authoring tool and `Carton` for managing module
dependencies.

## Development Environment
```bash
$ cpanm -n Carton
$ carton install
```

## How to Test
```bash
$ carton exec perl Build.PL
$ carton exec perl Build build
$ carton exec perl Build test
```

## How to REPL(Read-Eval-Print-Loop)
```bash
$ carton exec -- reply -Iblib/lib
```

## How to Format
```bash
$ carton exec perl author/format.pl
```

## How to Release to CPAN
```bash
$ carton exec minil test
$ carton exec -- minil release --dry-run
$ carton exec minil release
```

## Docker
```bash
$ docker build -t gimei .
$ docer run --rm -it -v$PWD:/gimei gimei bash -l
```
