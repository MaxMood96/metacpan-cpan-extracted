#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use Inline::CLIPS;

# This example mirrors the process-flow-check CLIPS project.  It defines
# flow-step, tool-capability, and violation templates, asserts a small
# photolithography/poly-etch flow, and runs rules that check for consistency
# and timing violations.
#
# For the full project see:
#   /home/jovan/devel/Clips_code/process-flow-check

my $clips = Inline::CLIPS->new;

my $result = $clips->run_program(
  q{
    (deftemplate flow-step
      (slot step-id (type INTEGER))
      (slot step-name)
      (slot layer)
      (slot tool-id)
      (slot recipe-id)
      (slot queue-time-min (type INTEGER))
      (slot max-wait-min (type INTEGER))
      (slot rework-allowed (allowed-values TRUE FALSE))
      (slot prev-step-id (type INTEGER) (default -1)))

    (deftemplate tool-capability
      (slot tool-id)
      (slot allowed-layers)
      (multislot allowed-recipes))

    (deftemplate violation
      (slot code)
      (slot message)
      (slot step-id)
      (slot severity (allowed-values info warning error)))

    ; Reference capabilities for the tool set.
    (deffacts reference-capabilities
      (tool-capability (tool-id CT-01)  (allowed-layers PHOTO)
                       (allowed-recipes CT-PR-193))
      (tool-capability (tool-id EX-05)  (allowed-layers PHOTO)
                       (allowed-recipes EX-193-NA13))
      (tool-capability (tool-id DEV-02) (allowed-layers PHOTO)
                       (allowed-recipes DEV-TMAH))
      (tool-capability (tool-id INS-01) (allowed-layers PHOTO)
                       (allowed-recipes INS-BF))
      (tool-capability (tool-id ETCH-07) (allowed-layers POLY)
                       (allowed-recipes ETCH-Cl2-BCl3)))

    ; A tool must be qualified for the step's layer.
    (defrule check-tool-layer
      (flow-step (step-id ?id) (layer ?layer) (tool-id ?tool))
      (tool-capability (tool-id ?tool) (allowed-layers ?allowed))
      (test (neq ?layer ?allowed))
      =>
      (assert (violation (code CONS-001)
                         (message "Tool not qualified for layer")
                         (step-id ?id)
                         (severity error))))

    ; Queue time must not exceed the maximum wait time.
    (defrule check-queue-time
      (flow-step (step-id ?id) (queue-time-min ?q) (max-wait-min ?m))
      (test (> ?q ?m))
      =>
      (assert (violation (code TIME-001)
                         (message "Queue time exceeds maximum wait")
                         (step-id ?id)
                         (severity error))))

    (deffunction print-report ()
      (bind ?errs (find-all-facts ((?v violation)) TRUE))
      (if (eq (length$ ?errs) 0)
        then
          (printout t "No violations found." crlf)
        else
          (printout t "Violations:" crlf)
          (foreach ?vf ?errs
            (printout t "[" (fact-slot-value ?vf code) "] @ step "
                      (fact-slot-value ?vf step-id) " — "
                      (fact-slot-value ?vf message) crlf))))

    ; A nominal photolithography + poly-etch flow.  Change queue-time-min on
    ; any step to a value larger than max-wait-min to trigger TIME-001, or
    ; assign a PHOTO step to ETCH-07 to trigger CONS-001.
    (deffacts current-flow
      (flow-step (step-id 10) (step-name Coat)    (layer PHOTO)
                 (tool-id CT-01)  (recipe-id CT-PR-193)
                 (queue-time-min 10) (max-wait-min 60)  (rework-allowed FALSE)
                 (prev-step-id -1))
      (flow-step (step-id 20) (step-name Expose)  (layer PHOTO)
                 (tool-id EX-05)  (recipe-id EX-193-NA13)
                 (queue-time-min 12) (max-wait-min 60)  (rework-allowed FALSE)
                 (prev-step-id 10))
      (flow-step (step-id 30) (step-name Develop) (layer PHOTO)
                 (tool-id DEV-02) (recipe-id DEV-TMAH)
                 (queue-time-min 8)  (max-wait-min 45)  (rework-allowed FALSE)
                 (prev-step-id 20))
      (flow-step (step-id 40) (step-name Inspect) (layer PHOTO)
                 (tool-id INS-01) (recipe-id INS-BF)
                 (queue-time-min 5)  (max-wait-min 30)  (rework-allowed TRUE)
                 (prev-step-id 30))
      (flow-step (step-id 50) (step-name Etch)    (layer POLY)
                 (tool-id ETCH-07) (recipe-id ETCH-Cl2-BCl3)
                 (queue-time-min 15) (max-wait-min 120) (rework-allowed FALSE)
                 (prev-step-id 40)))
  },
  '(reset)',
  '(run)',
  '(print-report)',
);

print $result->{stdout};
warn $result->{stderr} if $result->{stderr};
exit $result->{status};
