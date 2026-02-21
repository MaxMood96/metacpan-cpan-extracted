# nofork モードの実装と性能

## 概要

`Command::Run` に `nofork` オプションを追加。code ref の実行時に
`fork()` を使わず、STDOUT/STDERR/STDIN を tmpfile + dup で
リダイレクトして同一プロセス内で実行する。

## 性能比較: nofork vs fork

code ref を使った `run()` の比較（Benchmark モジュール、各3秒間実行）。

### 出力のみ（stdin なし）

| 出力サイズ | fork | nofork | 倍率 |
|-----------|-----:|-------:|-----:|
| 100B | 966/s | 27,272/s | 28x |
| 1KB | 94/s | 26,083/s | 277x |
| 10KB | 48/s | 14,391/s | 303x |
| 100KB | 37/s | 2,968/s | 80x |

### stdin あり

| サイズ | fork | nofork | 倍率 |
|--------|-----:|-------:|-----:|
| 100B | 35/s | 255/s | 7x |
| 1KB | 9.3/s | 70/s | 8x |
| 10KB | 6.3/s | 42/s | 7x |

### 速度差の要因

fork パスは毎回 `fork()` + `waitpid()` + `exit()` + パイプ I/O が
発生する。nofork パスはこれらがなく、dup によるリダイレクトと
tmpfile I/O のみで完結する。

stdin ありの場合、`with(stdin => ...)` による tmpfile 書き込みが
毎回発生するため、両者とも大幅に遅くなるが、nofork の方が速い。

## tmpfile 再利用の最適化

初期実装では呼び出しごとに最大3つの tmpfile を `new_tmpfile` で
作成していたため、繰り返し実行時に nofork が fork より遅かった。

### 修正内容

tmpfile をオブジェクト属性にキャッシュし、`//=` で初回のみ作成、
以降は `truncate + seek` で再利用:

| 属性 | 用途 | 条件 |
|------|------|------|
| `NOFORK_STDOUT` | stdout キャプチャ | 常に使用 |
| `NOFORK_STDERR` | stderr キャプチャ | `stderr eq 'capture'` 時のみ |
| `NOFORK_STDIN` | stdin リダイレクト | `exists $opt{stdin}` 時のみ |

```perl
my $tmp_stdout = $obj->{NOFORK_STDOUT} //= do {
    my $fh = new_tmpfile IO::File or die "tmpfile: $!\n";
    binmode $fh, ':encoding(utf8)';
    $fh;
};
$tmp_stdout->seek(0, 0)  or die "seek: $!\n";
$tmp_stdout->truncate(0) or die "truncate: $!\n";
```

### tmpfile 操作単体の比較

| 操作 | 速度 | 比率 |
|------|-----:|------|
| `3x new_tmpfile`（変更前） | 5,086/s | 1x（基準） |
| `3x truncate+seek`（変更後） | 186,090/s | **36x 高速** |

この最適化により、繰り返し実行時の nofork が fork より速くなった。

## その他の最適化

- STDERR/STDIN の save/restore は実際にリダイレクトする場合のみ実行
  （最小 dup 数: 7→3）
- `$0` の save/restore は `code_name` がある場合のみ実行

## 制限事項

- code が `exit()` を呼ぶとプロセスごと終了する
- `@ARGV` と `$0` 以外のグローバル状態の変更は残る
- 外部コマンドには適用されない（fork にフォールスルー）

## テスト結果

```
$ prove -l t/ xt/
t/00_compile.t .......... ok
t/01_tmpfile.t .......... ok
t/02_run.t .............. ok
t/03_coderef.t .......... ok
t/04_with.t ............. ok
t/05_nofork.t ........... ok
xt/nofork_ansicolumn.t .. ok
All tests successful.
Files=7, Tests=87
Result: PASS
```

## 計測環境

- macOS Darwin 24.6.0
- Perl 5.42.0
- Benchmark モジュール使用、wall clock 3秒間で計測
