# Skips shared by the test files (alignment rule R7 names).

# Skips a test that allocates heavily or holds a thousand handles. It checks
# a limit or a code path, not memory safety, and under gctorture or valgrind
# it would take hours; native-checks.yaml sets ZUPDF_SKIP_HEAVY for those
# jobs. Never on CRAN, whose machines are shared.
skip_heavy <- function() {
  skip_on_cran()
  skip_if(nzchar(Sys.getenv("ZUPDF_SKIP_HEAVY")), "ZUPDF_SKIP_HEAVY is set")
}

# Runs a slow test only when ZUPDF_SLOW_TESTS is set.
skip_if_no_slow_tests <- function() {
  skip_if_not(
    nzchar(Sys.getenv("ZUPDF_SLOW_TESTS")),
    "ZUPDF_SLOW_TESTS is not set"
  )
}

# Skips until the roadmap stage that exports `fn` lands, so a test can be
# written before the code it tests.
skip_until_exported <- function(fn) {
  skip_if_not(
    fn %in% getNamespaceExports("zupdf"),
    paste0(fn, "() is not implemented yet")
  )
}
