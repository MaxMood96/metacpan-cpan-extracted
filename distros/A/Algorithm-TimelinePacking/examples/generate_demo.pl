#!/usr/bin/env perl
#
# Generate a demo HTML file showing timeline visualization
# Usage: carton exec perl examples/generate_demo.pl > examples/demo.html
#
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Algorithm::TimelinePacking;
use JSON::XS;

# Generate sample job data simulating a Hadoop cluster
my @users = qw(alice bob carol dave eve);
my @slices;

# Base timestamp (arbitrary, will be normalized anyway)
my $base = 1700000000;

# Generate 50 random jobs
srand(42);  # reproducible results
for my $i (1..50) {
    my $start    = $base + int(rand(3600));         # within 1 hour
    my $duration = 30 + int(rand(300));             # 30s to 5min
    my $end      = $start + $duration;
    my $user     = $users[int(rand(@users))];
    my $maps     = 10 + int(rand(5000));
    my $reduces  = 1 + int(rand(500));

    push @slices, [$start, $end, "job_$i", $user, $maps, $reduces];
}

# Arrange slices using Timeline
my $timeline = Algorithm::TimelinePacking->new(space => 2);
my ($lines, $latest) = $timeline->arrange_slices(\@slices);

# Convert to JSON
my $json = JSON::XS->new->utf8->pretty->encode($lines);
my $width = 1200;

# Generate complete HTML document
print <<"HTML";
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Timeline Demo</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }
        h1 {
            color: #333;
        }
        .info {
            margin-bottom: 20px;
            color: #666;
        }
        #chart {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        svg {
            overflow: visible;
        }
        rect {
            stroke: #fff;
            stroke-width: 0.5;
        }
        rect:hover {
            stroke: #000;
            stroke-width: 2;
        }
    </style>
</head>
<body>
    <h1>Timeline Visualization Demo</h1>
    <div class="info">
        <p>50 simulated Hadoop jobs arranged on ${\(scalar @$lines)} lines.
           Hover over bars to see job details.</p>
        <p>Color intensity represents map task count (gray → red = few → many).</p>
    </div>
    <div id="chart">
        <svg id="timeline" width="$width"></svg>
    </div>

<script>
(function() {
    const LINE_HEIGHT = 20;
    const BAR_HEIGHT = 18;
    const SCALE_DIVISOR = 3;  // adjust based on data range
    const INTENSITY_MAX = 5000;

    const myData = $json;

    const levelColor = d3.scaleLinear().domain([1, INTENSITY_MAX]).range([0, 1]);

    const svgHeight = myData.length * LINE_HEIGHT;
    d3.select("#timeline").attr("height", svgHeight);

    myData.forEach(function(line, idx) {
        const lineGroup = d3.select("#timeline")
            .append("g")
            .attr("id", "line_" + idx)
            .attr("transform", "translate(0," + (idx * LINE_HEIGHT) + ")");

        lineGroup.selectAll("rect")
            .data(line)
            .enter()
            .append("rect")
            .style("fill", function(d) {
                if (d[4] > INTENSITY_MAX) return "#f00";
                return d3.interpolateLab("#eee", "#f00")(levelColor(d[4]));
            })
            .attr("height", BAR_HEIGHT)
            .attr("width", function(d) {
                return Math.max(2, d[1] / SCALE_DIVISOR - d[0] / SCALE_DIVISOR);
            })
            .attr("x", function(d) {
                return d[0] / SCALE_DIVISOR;
            })
            .attr("y", 0)
            .attr("rx", 2)
            .attr("ry", 2)
            .append("title")
            .text(function(d) {
                return "Job: " + d[2] + "\\nUser: " + d[3] + "\\nMaps: " + d[4] + "\\nReduces: " + d[5];
            });
    });
})();
</script>
</body>
</html>
HTML
