context("Promise extraction")

`%is%` <- expect_equal

test_that("can register arguments to actual environments", {

  f1 <- function(a, ...) { #a=one@top, two@top
    b <- 1
    where = "f1"
    f2(b, where, ...) #b, where, two
  }
  f2 <- function(a, ...) { # a=b@f1, where@f1, two@top
    b <- 2
    where <- "f2"
    f3(b, where, ...) #b@f2, where@f2, where@f1, two@top
  }
  f3 <- function(a, b, c, ...) { #a=b@f2, b=where@f2, c=where@f1, two@top
    arg_expr(a) %is% quote(b)
    arg_expr(b) %is% quote(where)
    arg_expr(c) %is% quote(where)
    dots_expressions(...) %is% alist(two)
    arg_env(a)$where %is% "f2"
    arg_env(b)$where %is% "f2"
    arg_env(c)$where %is% "f1"
    dots_environments(...)[[1]]$where %is% "top"
  }
  where <- "top"
  f1(one, two)

})

test_that("arg_env error on evaluated promise", {
  f1 <- function(x) arg_env(x)
  f2 <- function(...) {
    list(...)
    f1(...)
  }
  expect_error(f2(124), "evaluated")
})

test_that("empty arguments return missing value and empty environment", {
  f1 <- function(x) arg_env(x)
  f2 <- function(x) arg_expr(x)
  expect_identical(f1(), emptyenv())
  expect_identical(f2(), missing_value())
})

test_that("get dotslists of args direct or by name", {
  stop("not written")
})

test_that("get dotslists handles missing arguments by making blank promises", {
  stop("not written")
})

test_that("get all arguments, named or no, of present env", {
  stop("not written")
})
