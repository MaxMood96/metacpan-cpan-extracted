use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/JSON/Schema/Modern.pm',
    'lib/JSON/Schema/Modern/Annotation.pm',
    'lib/JSON/Schema/Modern/Document.pm',
    'lib/JSON/Schema/Modern/Error.pm',
    'lib/JSON/Schema/Modern/Result.pm',
    'lib/JSON/Schema/Modern/ResultNode.pm',
    'lib/JSON/Schema/Modern/Utilities.pm',
    'lib/JSON/Schema/Modern/Vocabulary.pm',
    'lib/JSON/Schema/Modern/Vocabulary/Applicator.pm',
    'lib/JSON/Schema/Modern/Vocabulary/Content.pm',
    'lib/JSON/Schema/Modern/Vocabulary/Core.pm',
    'lib/JSON/Schema/Modern/Vocabulary/FormatAnnotation.pm',
    'lib/JSON/Schema/Modern/Vocabulary/FormatAssertion.pm',
    'lib/JSON/Schema/Modern/Vocabulary/MetaData.pm',
    'lib/JSON/Schema/Modern/Vocabulary/Unevaluated.pm',
    'lib/JSON/Schema/Modern/Vocabulary/Validation.pm',
    'script/json-schema-eval',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/add-schema.t',
    't/additional-tests-draft2019-09.t',
    't/additional-tests-draft2019-09/README',
    't/additional-tests-draft2019-09/anchor.json',
    't/additional-tests-draft2019-09/annotation-collection.json',
    't/additional-tests-draft2019-09/badRef.json',
    't/additional-tests-draft2019-09/faux-buggy-schemas.json',
    't/additional-tests-draft2019-09/format-date-time.json',
    't/additional-tests-draft2019-09/format-date.json',
    't/additional-tests-draft2019-09/format-duration.json',
    't/additional-tests-draft2019-09/format-ipv4.json',
    't/additional-tests-draft2019-09/format-ipv6.json',
    't/additional-tests-draft2019-09/format-relative-json-pointer.json',
    't/additional-tests-draft2019-09/format-time.json',
    't/additional-tests-draft2019-09/formats.json',
    't/additional-tests-draft2019-09/id.json',
    't/additional-tests-draft2019-09/integers.json',
    't/additional-tests-draft2019-09/keyword-independence.json',
    't/additional-tests-draft2019-09/loose-types-const-enum.json',
    't/additional-tests-draft2019-09/recursive-dynamic.json',
    't/additional-tests-draft2019-09/ref-and-id.json',
    't/additional-tests-draft2019-09/ref.json',
    't/additional-tests-draft2019-09/short-circuit.json',
    't/additional-tests-draft2019-09/unknownKeyword.json',
    't/additional-tests-draft2019-09/vocabulary.json',
    't/additional-tests-draft2020-12.t',
    't/additional-tests-draft2020-12/README',
    't/additional-tests-draft2020-12/anchor.json',
    't/additional-tests-draft2020-12/annotation-collection.json',
    't/additional-tests-draft2020-12/badRef.json',
    't/additional-tests-draft2020-12/dynamicRef.json',
    't/additional-tests-draft2020-12/faux-buggy-schemas.json',
    't/additional-tests-draft2020-12/format-date-time.json',
    't/additional-tests-draft2020-12/format-date.json',
    't/additional-tests-draft2020-12/format-duration.json',
    't/additional-tests-draft2020-12/format-ipv4.json',
    't/additional-tests-draft2020-12/format-ipv6.json',
    't/additional-tests-draft2020-12/format-relative-json-pointer.json',
    't/additional-tests-draft2020-12/format-time.json',
    't/additional-tests-draft2020-12/formats.json',
    't/additional-tests-draft2020-12/id.json',
    't/additional-tests-draft2020-12/integers.json',
    't/additional-tests-draft2020-12/keyword-independence.json',
    't/additional-tests-draft2020-12/loose-types-const-enum.json',
    't/additional-tests-draft2020-12/recursive-dynamic.json',
    't/additional-tests-draft2020-12/ref-and-id.json',
    't/additional-tests-draft2020-12/ref.json',
    't/additional-tests-draft2020-12/short-circuit.json',
    't/additional-tests-draft2020-12/unknownKeyword.json',
    't/additional-tests-draft2020-12/vocabulary.json',
    't/additional-tests-draft4.t',
    't/additional-tests-draft4/format-date-time.json',
    't/additional-tests-draft4/format-ipv4.json',
    't/additional-tests-draft4/format-ipv6.json',
    't/additional-tests-draft4/id.json',
    't/additional-tests-draft4/integers.json',
    't/additional-tests-draft4/type.json',
    't/additional-tests-draft7.t',
    't/additional-tests-draft7/README',
    't/additional-tests-draft7/badRef.json',
    't/additional-tests-draft7/faux-buggy-schemas.json',
    't/additional-tests-draft7/format-date-time.json',
    't/additional-tests-draft7/format-date.json',
    't/additional-tests-draft7/format-ipv4.json',
    't/additional-tests-draft7/format-relative-json-pointer.json',
    't/additional-tests-draft7/format-time.json',
    't/additional-tests-draft7/id.json',
    't/additional-tests-draft7/integers.json',
    't/additional-tests-draft7/keyword-independence.json',
    't/additional-tests-draft7/loose-types-const-enum.json',
    't/additional-tests-draft7/not-an-anchor.json',
    't/additional-tests-draft7/not-an-id.json',
    't/additional-tests-draft7/ref-and-id.json',
    't/additional-tests-draft7/ref.json',
    't/additional-tests-draft7/short-circuit.json',
    't/additional-tests-draft7/unknownKeyword.json',
    't/additional-tests-draft7/vocabulary.json',
    't/annotations.t',
    't/boolean-data.t',
    't/boolean-schemas.t',
    't/cached-metaschemas.t',
    't/callbacks.t',
    't/checksums.t',
    't/content-encoding.t',
    't/dialects.t',
    't/document.t',
    't/equality.t',
    't/errors.t',
    't/evaluate_json_string.t',
    't/find-identifiers.t',
    't/formats.t',
    't/invalid-schemas.t',
    't/invalid-schemas/invalid-input.json',
    't/invalid-schemas/ref.json',
    't/invalid-schemas/vocabulary.json',
    't/lib/Acceptance.pm',
    't/lib/Helper.pm',
    't/lib/MyVocabulary/BadEvaluationOrder.pm',
    't/lib/MyVocabulary/BadVocabularySub1.pm',
    't/lib/MyVocabulary/BadVocabularySub2.pm',
    't/lib/MyVocabulary/BadVocabularySub3.pm',
    't/lib/MyVocabulary/ConflictingKeyword.pm',
    't/lib/MyVocabulary/MissingRole.pm',
    't/lib/MyVocabulary/MissingSub.pm',
    't/lib/MyVocabulary/ReservedKeyword.pm',
    't/lib/MyVocabulary/StringComparison.pm',
    't/max_traversal_depth.t',
    't/multipleOf.t',
    't/output_format.t',
    't/pattern.t',
    't/read_serialized_file',
    't/ref.t',
    't/results/draft2019-09-acceptance-format.txt',
    't/results/draft2019-09-acceptance.txt',
    't/results/draft2019-09-additional-tests.txt',
    't/results/draft2019-09-invalid-schemas.txt',
    't/results/draft2020-12-acceptance-format.txt',
    't/results/draft2020-12-acceptance.txt',
    't/results/draft2020-12-additional-tests.txt',
    't/results/draft2020-12-invalid-schemas.txt',
    't/results/draft4-acceptance-format.txt',
    't/results/draft4-acceptance.txt',
    't/results/draft4-additional-tests.txt',
    't/results/draft6-acceptance-format.txt',
    't/results/draft6-acceptance.txt',
    't/results/draft7-acceptance-format.txt',
    't/results/draft7-acceptance.txt',
    't/results/draft7-additional-tests.txt',
    't/serialization.t',
    't/specification_version.t',
    't/strict.t',
    't/stringy-numbers.t',
    't/traverse.t',
    't/type.t',
    't/unsupported-keywords.t',
    't/validate-schema.t',
    't/vocabularies.t',
    't/zzz-acceptance-draft2019-09-format.t',
    't/zzz-acceptance-draft2019-09.t',
    't/zzz-acceptance-draft2020-12-format.t',
    't/zzz-acceptance-draft2020-12.t',
    't/zzz-acceptance-draft4-format.t',
    't/zzz-acceptance-draft4.t',
    't/zzz-acceptance-draft6-format.t',
    't/zzz-acceptance-draft6.t',
    't/zzz-acceptance-draft7-format.t',
    't/zzz-acceptance-draft7.t',
    't/zzz-check-breaks.t',
    'xt/author/00-compile.t',
    'xt/author/clean-namespaces.t',
    'xt/author/distmeta.t',
    'xt/author/eol.t',
    'xt/author/kwalitee.t',
    'xt/author/minimum-version.t',
    'xt/author/mojibake.t',
    'xt/author/no-tabs.t',
    'xt/author/pod-coverage.t',
    'xt/author/pod-spell.t',
    'xt/author/pod-syntax.t',
    'xt/author/portability.t',
    'xt/release/changes_has_content.t',
    'xt/release/cpan-changes.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
