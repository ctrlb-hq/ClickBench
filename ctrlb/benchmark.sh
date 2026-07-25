#!/bin/bash
#
# ClickBench entry point for CtrlB (Parquet, single). Sets the harness env vars,
# runs the shared ClickBench driver, then turns its output into
# results/<UTC date>/<machine>.json — so one ./benchmark.sh yields a result file
# you can read exactly like the other engines' (see make-result.py).
#
# CtrlB is a long-lived HTTP daemon whose session state (the `hits` view +
# metadata cache) is wiped on restart, so we run RESTARTABLE=yes for a fresh,
# cold session per query. The schema/footer parse happens in the UNtimed ./start
# (via create.sql), so the cold-query number measures the data scan, not footer
# parsing — the same treatment the other read-in-place Parquet engines get. The
# data is the on-disk hits.parquet, read in place, so DURABLE=yes (no per-query
# reload) and the `hits` view is (re)created in ./start after each restart.

export BENCH_DOWNLOAD_SCRIPT="download-hits-parquet-single"
export BENCH_RESTARTABLE=yes
export BENCH_DURABLE=yes
export BENCH_TRIES="${BENCH_TRIES:-3}"
# Concurrent-QPS probe disabled (BENCH_CONCURRENT_DURATION=0). This Parquet-single
# config prioritizes single-query latency (unbounded, no-spill memory pool), so
# 10 concurrent heavy queries exhaust the box's RAM; we therefore report only the
# cold/hot numbers and leave concurrent_qps null — consistent with the DataFusion
# family, which also reports null here.
export BENCH_CONCURRENT_DURATION="${BENCH_CONCURRENT_DURATION:-0}"

# Run the shared ClickBench driver, capturing stdout so we can BOTH show it live
# and turn it into the committed results JSON. `tee` preserves the standard text
# output (Load time / [t1,t2,t3] / Data size); PIPESTATUS keeps the driver's real
# exit code (tee's is always 0).
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG="${CTRLB_RESULT_LOG:-$HERE/run.log}"

../lib/benchmark-common.sh | tee "$LOG"
status=${PIPESTATUS[0]}

# Assemble results/<UTC date>/c6a.4xlarge.json from the captured log + template.json,
# so the result is readable exactly like the other engines'. Non-fatal: if this
# can't run, the raw log ($LOG) is still there to convert by hand with
# make-result.py.
if [ "$status" -ne 0 ]; then
  echo "WARN: benchmark driver exited $status — not writing results JSON." >&2
elif ! command -v python3 > /dev/null 2>&1; then
  echo "WARN: python3 not found — run: python3 make-result.py \"$LOG\"" >&2
else
  python3 "$HERE/make-result.py" "$LOG" --machine "${CTRLB_MACHINE:-c6a.4xlarge}" \
    || echo "WARN: results JSON not written; run: python3 make-result.py \"$LOG\"" >&2
fi

exit "$status"
