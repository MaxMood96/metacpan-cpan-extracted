#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer2;
use Uniform::HTMX::Dancer2;

get '/' => sub {
    if (is_htmx) {
        htmx->res_trigger('greetingLoaded', { time => scalar localtime });
        return '<div id="content" class="p-4 bg-green-100 text-green-800 rounded border border-green-300">Hello from HTMX partial!</div>';
    }

    return <<'HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Uniform::HTMX::Dancer2 Demo</title>
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="p-8 bg-gray-50 text-gray-800">
    <div class="max-w-md mx-auto bg-white p-6 rounded shadow">
        <h1 class="text-2xl font-bold mb-4">Uniform::HTMX::Dancer2 Demo</h1>
        <div id="content" class="mb-4 text-gray-600">Initial full page load.</div>
        <button hx-get="/" hx-target="#content" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
            Fetch HTMX Partial
        </button>
    </div>
</body>
</html>
HTML
};

start;
