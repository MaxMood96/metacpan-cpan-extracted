use strict;
use warnings;

our $t1_expected = <<'LIQUID';
<wbr>
<a href="{% if site.github %}{{ site.github.tar_url | replace_first: '/tarball/', '/tree/' }}{% else %}file://{{ site.source }}{%
    endif
    %}/{% if page.relative_path %}{{ page.relative_path }}{%
    elsif paginator and paginator.page > 1 %}{%
        assign temp0 = "/" | append: paginator.page | append: "/"
        %}{{ page.path | replace_first: temp0, "/" }}{% else %}{{ page.path }}{%
    endif
%}">Source file</a>.
LIQUID

our $t2_expected = <<'LIQUID';
<wbr>
<a href="{%
    if site.github
        %}{{ site.github.tar_url | replace_first: '/tarball/', '/tree/' }}{%
    else
        %}file://{{ site.source }}{%
    endif
    %}/{%
    if page.relative_path
        %}{{ page.relative_path }}{%
    elsif paginator and paginator.page > 1 %}{%
        assign temp0 = "/" | append: paginator.page | append: "/"
        %}{{ page.path | replace_first: temp0, "/" }}{%
    else
        %}{{ page.path }}{%
    endif
%}">Source file</a>.
LIQUID

1;
