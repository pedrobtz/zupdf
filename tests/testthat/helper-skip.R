# Skips shared by the test files (alignment rule R7 names).

# Skips a test that allocates heavily or holds a thousand handles. It checks
# a limit or a code path, not memory safety, and under gctorture or valgrind
# it would take hours; native-checks.yaml sets ZUPDF_SKIP_HEAVY for those
# jobs. Never on CRAN, whose machines are shared.
skip_heavy <- function() {
  skip_on_cran()
  skip_if(nzchar(Sys.getenv("ZUPDF_SKIP_HEAVY")), "ZUPDF_SKIP_HEAVY is set")
}
