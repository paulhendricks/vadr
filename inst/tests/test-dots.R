context("dots")

`%is%` <- expect_equal

unwind_protect <- function(body, unwind) {
  on.exit(unwind)
  body
}

##Quickie macro to help with setup and teardown.
with_setup <- macro(JIT=FALSE, function(setup=NULL, ..., teardown=NULL) {
  qq({
    ...( lapply(list(...), function(x) qq({
      .(setup)
      .(unwind_protect)(.(x), .(teardown))
    })))
  })
})

## DOTSXP UNPACKING --------------------------------------------------

test_that("dots_unpack() method extracts dots information into a data frame", {
  expect_equal(nrow(dots_unpack()), 0)
  f <- function(...) {
    list(dots_unpack(...), environment())
  }
  x <- 2
  y <- 3
  bind[di, env] <- f(x, y=3, z=x+y)
  env <- environment()

  expect_identical(di$expr[[1]], quote(x))
  expect_identical(di$expr[[2]], quote(3))
  expect_identical(di$expr[[3]], quote(x+y))
  expect_identical(di$env[[3]], env)
  expect_identical(di$env[[3]], env)
  expect_identical(di$env[[3]], env)
  expect_identical(di$value[[1]], NULL)
  expect_identical(di$value[[2]], NULL)
  expect_identical(di$value[[3]], NULL)
  expect_identical(di$name[[1]], "")
  expect_identical(di$name[[2]], "y")
  expect_identical(di$name[[3]], "z")
})

test_that("dots_unpack(...) exposes promise behavior", {
  a <- 12
  b <- a+2
  unpack_fns <- function(...) {
    #get functions that to things to the same dotslist
    list(
      function() dots_unpack(...),
      function() (function(x, ...) x)(...),
      function() list(...),
      environment()
      )}
  outer_env <- environment()
  bind[reunpack, eval_x, eval_all, inner_env] <- unpack_fns(x=a, y=a+2)

  du <- reunpack()
  expect_identical(du$value[[1]], NULL)
  expect_identical(du$env[[1]], outer_env)
  eval_x()
  du2 <- reunpack()
  expect_identical(du2$value[[1]], 12)
  expect_identical(du2$envir[[1]], NULL)
  expect_identical(du2$envir[[2]], outer_env)
  expect_identical(du2$value[[2]], NULL)
})

test_that("dots_unpack has a print method that works", {
  capture.output(dots_unpack(a, b, c, d, 4, e)) #should go without error
})

test_that("dots_unpack(...) descends through promise chains if necessary", {
  y <- 1
  f1 <- function(...) {
    x <- 1
    list(getdots(y=x+1, ...), environment())
  }
  getdots <- function(...) dots_unpack(...)

  bind[du, f1_env] <- f1(a=y+z)

  expect_identical(du[["a", "envir"]], environment())
  expect_identical(du[["y", "envir"]], f1_env)
  #"substitute" here extracts the expression from compiled bytecode
  #(which a promise may contain) Maybe I should try to get the expressions out..
  expect_true(identical(du[["a", "expr"]], quote(y+z))
              || "bytecode" %in% mode(du[["a", "expr"]]))
  expect_true(identical(du[["y", "expr"]], quote(x+1))
              || "bytecode" %in% class(du[["y", "expr"]]))
})

## these should also be in reference to dots objects
test_that("dots_missing", {
  expect_equivalent(logical(0), dots_missing())
  with_setup(
    setup={
      if (exists("a")) rm(a)
      unmissing <- 1
      b <- missing_value()
    },
    #test both the dots_missing form and the is.missing.... form
    thunk <- dots_missing,
    thunk <- function(...) is.missing....(dots(...)),
    #actual testing in the teardown
    teardown={
      expect_equal(c(   FALSE, FALSE,     c=TRUE, FALSE, d=FALSE, TRUE),
                   thunk(   a, unmissing, c=,     4,     d=x+y,       ))

      #this currently (R 2.15.2) answers "b" differently in some cases.
      #My opionion is this is a bug in R, so don't check right now.
      ## wrap <- function(...) {
      ##   thunk(...)
      ## }
      ## #                                   *WHAT*
      ## expect_equal(c(   FALSE, FALSE,     FALSE, c=TRUE, FALSE, d=FALSE, TRUE),
      ##              wrap(    a, unmissing, b,     c=,     4,     d=x+y,       ))

      #And this check for missingness does not eval
      expect_equal(c(FALSE, c=TRUE, FALSE),
                   thunk(stop("no"), c=, stop("no")))
      rm(unmissing)
      rm(b)
    })})

test_that("dots_names", {
  expect_equal(c("", "", "c", "", "d", ""),
               dots_names(a, b, c=, 4, d=x+y, ) )

  #and dots_names does not eval dots
  expect_equal(c("", "a"),
               dots_names(stop("no"), a=stop("no")))
  expect_equivalent(NULL, dots_names())
})

test_that("is.missing on non-dotlists", {
  a <- alist(1, 2, adsf, , b=, )
  is.missing(a) %is% c(FALSE, FALSE, FALSE, TRUE, b=TRUE, TRUE)
  b <- c(1, 2, NA, NaN)
  is.missing(b) %is% c(FALSE, FALSE, FALSE, FALSE)
  is.missing() %is% TRUE
  is.missing(function(x) y) %is% FALSE
})

test_that("list_missing", {
  expect_equal(list_missing(1, 2, 3),
               list(1,2,3))

  expect_equal(list_missing(1, 2, , "three"),
               alist(1, 2, , "three"))

  expect_equal(list_missing(a="one", b=, "three"),
               alist(a="one", b=, "three"))
})

test_that("list_missing evaluates arguments in the original scopes", {
  fOne <- function(...) {
    fThree <- function(...) {
      x <- "three"
      list_missing(..., three=x)
    }
    fTwo <- function(...) {
      x <- "two"
      fThree(..., two=x)
    }
    x <- "one"
    fTwo(..., one=x)
  }

  x <- "four"
  expect_equal(fOne(four=x),
               list(four="four", one="one", two="two", three="three"))
})

test_that("dots_expressions", {
  x <- 4
  f <- function(x, ...) {dots_expressions(...)}
  f(one, two, y=x<-3) %is% alist(two, y=x<-3)
  x %is% 4
  f <- function(x, ...) {expressions(dots(...))}
  f(one, two, y=x<-3) %is% alist(two, y=x <-3)
  x %is% 4
})

test_that("expression mutator", local({

  f <- function(...) {
    x <- dots(...)
    y <- x
    expressions(x) <- qqply(
      `.(paste0("temp",x))` <- .(e)
      )(e=expressions(x), x=seq_along(x))
    list %()% x
    unpack(x)
  }
  e1 <- NULL
  e2 <- NULL
  f1 <- function(...) {
    where <- "f1"
    temp1 <- 40
    temp2 <- 30
    e1 <<- environment()
    f(20, ...)
  }
  f2 <- function(...) {
    where <- "f2"
    temp1 <- 2
    temp2 <- 3
    e2 <<- environment()
    x <- f1(5, ...)
  }
  test <- f2()

  e2$temp2 %is% 5
  e1$temp1 %is% 20

  #error to set expressions for fulfilled promises
  forced <- function(...) {list(...); dots(...)}
  r <- 3
  x <- forced(r+2)
  y <- dots(r+2)
  expect_error(expressions(x) <- alist(r+1))
  expressions(y) <- alist(r+1)
  y[[1]] %is% 4

}))

test_that("dots_environments and mutator", local({
  expect_equivalent(dots_environments(), list())
  f1 <- function(...) {
    where <- "e1E"
    f2(..., toupper(where))
  }
  f2 <- function(...) {
    where <- "e2E"
    f(..., tolower(where))
  }
  f <- function(..., accessor=dots) {
    accessor(...)
  }

  test <- f1()
  environments(test)[[1]]$where %is% "e1E"
  environments(test)[[2]]$where %is% "e2E"
  as.list(test) %is% list("E1E", "e2e")

  test <- f1(accessor=dots_environments)
  test[[1]]$where %is% "e1E"
  test[[2]]$where %is% "e2E"

  test <- f1()
  environments(test) <- rev(environments(test))
  as.list(test) %is% list("E2E", "e1e")
}))

test_that("expressions unpacks bytecode", {
  f <- function(x) dots(y=x+1)
  f <- compiler::cmpfun(f)
  expressions(f(5)) %is% alist(y=x+1)
})

test_that("list_quote", {
  a <- list_quote(a, b, d=c, d, e)
  f <- function(a, b, ...) list_quote(a+b, ...)
  b <- f(x, y, z, foo, wat=bar)
  expect_equal(a, alist(a, b, d=c, d, e))
  expect_equal(b, alist(a+b, z, foo, wat=bar))
})

## DOTS OBJECT, CALLING AND CURRYING -------------------------------------

test_that("%()% is like do.call(quote=TRUE) but doesn't overquote", {
  x <- 2
  y <- 5

  ff <- function(x, y) list(substitute(x), substitute(y))

  list %()% list(x, y) %is% list(2,5)
  list %()% alist(x, y) %is% ff(x, y)
  list %()% ff(x, y+z) %is% ff(x, y+z)
  ff %()% ff(x, y) %is% ff(x, y)
  ff %()% list(x,y) %is% ff(2, 5)
})

test_that("x <- dots() captures dots and %()% calls with dots", {
  x <- 1;
  y <- 3;
  f <- `/`
  d <- dots(y=x, 4)
  f %()% d %is% 0.25
})

test_that("%()% and %<<% on vectors respects tags", {
  paste %()% c(sep="monkey", 1, 2, 3) %is% "1monkey2monkey3"
  c %<<% c(a=1) %()% c(b=2) %is% c(b=2, a=1)
  c %<<<% c(a=1) %()% c(b=2) %is% c(a=1, b=2)
})

test_that("curr and curl", {
  #these are versions that don't dispatch
  f <- curr(`/`)
  g <- curr(`/`)
  expect_error(f(5))
  expect_error(f())
  expect_error(g(5))
  expect_error(g())
  f <- curr(`/`, 2)
  g <- curl(`/`, 2)
  expect_error(f())
  expect_error(g())
  f(5) %is% 2.5
  g(5) %is% 0.4
})

test_that("curry DTRT with original scope of its arguments", {
  with_setup(
    setup={
      g <- function(...) {
        x <- "this is not in f"
        thunk(c, ...)
      }

      f <- function(...) {
        x <- "this is in f"
        g(this_x_should_be_scoped_in_f = x, ...)
      }
    },
    #for each variant of curry
    thunk <- curl,
    thunk <- curr,
    thunk <- function(f, ...) f %<<% dots(...),
    thunk <- function(f, ...) f %<<<% dots(...),
    #the actual test is in the teardown...
    teardown={
      f()() %is% c(this_x_should_be_scoped_in_f = "this is in f")
      length(f(a=1)()) %is% 2
    }
)})

test_that("as.dots() converts expressions to dotslists w.r.t. a given env", {
  x <- 3
  f1 <- function(l) {
    x <- 1
    as.dots(l)
  }
  f2 <- function(l) {
    x <- 2
    as.dots(l)
  }
  c %()% f1(alist(x)) %is% 1
  c %()% f2(alist(x)) %is% 2
  c %()% as.dots(alist(x)) %is% 3
})

test_that("as.dots() is idempotent on dots objects", {
  x <- 3
  l <- as.dots(alist(x))
  f <- function(l) {
    x <- 4
    as.dots(l)
  }
  l <- f(l)
  x <- 5
  c %()% l %is% 5
})

test_that("as.dots.literal puts literal things into dots", {
  list %()% as.dots.literal(alist(a, b, c, d)) %is% alist(a,b,c,d)
  list %()% as.dots.literal(list(quote(...))) %is% list(quote(...))
})

test_that("Curried dots evaluate like promises", {
  with_setup(
    setup={
      bind[w, x, y, z] <- c(2, 3, 4, 5)
      d <- dots(w+x)
      dd <- dots(w+x, y+z)
      f <- `*` %<<% d
      f2 <- `*` %<<% dd
    },
    {
      f2() %is% 45
      x <- 4
      f(y+z) %is% 54
    },
    {
      x <- 4
      f2() %is% 54
      f(2) %is% 12
      x <- 3
      (f %()% d) %is% 36
    },
    {
      #left-curry applies to the left of the arglist
      f2 <- `/` %<<<% dots(w+x)
      x <- 2
      f2(2) %is% 2
      x <- 3
      f2(2) %is% 2
    })
})

test_that("Curry operators concatenate dots, dots stay attached to envs", {
  with_setup(
    setup={
      envl <- list2env(structure(as.list(letters), names=letters))
      envu <- list2env(structure(as.list(LETTERS), names=letters))
      envn <- list2env(structure(as.list(1:10), names=letters[1:10]))
      l <- evalq(dots(a, b, c), envl)
      u <- evalq(dots(a, b, c), envu)
      n <- evalq(dots(a, b, c), envn)
      P <- paste %<<% list(sep="")
    },
    P  %()%  l  %is%  "abc",
    P  %()%  u  %is%  "ABC",
    P  %()%  n  %is%  "123",
    #these two cases are bothersome.
    P  %<<%  l  %<<%  u  %()%  n  %is%  "123ABCabc", #this is not intuitive?
    P  %<<<% u  %<<<% l  %()%  n  %is%  "ABCabc123",
    P  %<<<% l  %<<%  u  %()%  n  %is%  "abc123ABC",
    P  %<<<% (u %__% l)  %()%  n  %is%  "ABCabc123",
    P  %<<% (u %__% l)   %()%  n  %is%  "123ABCabc"
    )
})

test_that("%__% with mixed sequence types", {
  with_setup(
    setup={
      x <- "a"; y <- "b"; z <- "c"
      a <- dots(x, y, z)
      b <- LETTERS[4:6]
    },
    paste0 %()% (a %__% b) %is% "abcDEF",
    paste0 %()% (b %__% a) %is% "DEFabc",
    {x <- "_"; paste0 %()% (b %__% a) %is% "DEF_bc"},
    {x <- "_"; paste0 %()% (a %__% b) %is% "_bcDEF"}
    )
})

test_that("dots has some kind of print method", {
  d <- dots(a, b, c)
   capture.output(print(d))
})

test_that("dots() et al with empty inputs", {
  #note that there isn't such a thing as an empty dotslist, and this
  #(a) complicates evaluating "..." etc, and (b) complicates making a
  #dotslist the basis of the class (as it will have to be something
  #else to match a zero value.
  #So test variants of dots apply, curry, and cdots, with  empty dotslists.
  f <- function(x=4, y=2) x * y
  a <- dots()
  b <- as.dots(c())
  c <- list(1);
  d <- dots(2);

  f %()% a %is% 8
  f %()% b %is% 8
  (f %<<<% a)() %is% 8
  (f %<<% b)() %is% 8
  f %()% (b %__% a) %is% 8
  (f %<<% list())() %is% 8
  (f %<<<% list())() %is% 8
  f %()% (c %__% list()) %is% 2
  f %()% (list() %__% d) %is% 4
  f %()% (a %__% c) %is% 2
  f %()% (c %__% a) %is% 2
  f %()% (a %__% d) %is% 4
  f %()% (d %__% a) %is% 4
})

test_that("dots() on empty arguments", {
  x <- dots(, b=3)
  expect_identical(expressions(x), list(missing_value(), b=3))
  expect_equal(environments(x), list(emptyenv(), b=environment()))
  y <- x[1]
  names(y) <- "foo"
  expect_identical(expressions(y), list(foo=missing_value()))

  if (FALSE) {
    #these are classified as R bugs for now.
    #https://bugs.r-project.org/bugzilla3/show_bug.cgi?id=15707
    m1 <- function(x,y,z) c(missing(x), missing(y), missing(z))
    m2 <- function(...) dots_missing(...)

    dots_other <- function(x, y, z) {
      arg_dots(x, y, z) #makes promises set to R_MissingValue
    }

    d1 <- dots(x, , z) #currently, makes
    d2 <- dots_other(x, , z)

    m1(one, , three) #FALSE, TRUE, FALSE
    m2(one, , three) #FALSE, FALSE, FALSE
    (function(...) m1(...))(one, , three) #FALSE, TRUE, FALSE
    (function(...) m2(...))(one, , three) #FALSE, FALSE, FALSE
    (function(...) (function(...) m1(...))(...))(one, , three)
    #FALSE, FALSE, FALSE but these last two are on R
    m1 %()% d1 #FALSE, TRUE, FALSE
    m1 %()% d2 #FALSE, FALSE, FALSE
    m2 %()% d1 #FALSE, FALSE, FALSE
    m2 %()% d2 #FALSE, FALSE, FALSE
    do.call(m1, alist(one, , three)) #FALSE, TRUE, FALSE
    do.call(m2, alist(one, , three)) #FALSE, TRUE, FALSE
  }

})

test_that("dots methods on empty dots", {
  x <- dots()
  is.missing(x) %is% logical(0)
  names(x) %is% NULL
  expect_that(expressions(x), is_equivalent_to(list()))
  test_that(unpack(x),
            is_equivalent_to(list(
                name=character(0), envir=list(), expr=list(), value=list())))
  x[] %is% x
  y <- dots(1, 2, 3)
  list %()% y[c()] %is% list()
})

test_that("dots [] operator subsets without forcing promises", {
  with_setup(
    setup= {
      a <- dots(x, r=y, x+y)
      x <- 3
      y <- 4
    }, {
      c %()% a[1:2] %is% c(3,r=4)
       x <- 4
      c %()% a[3] %is% 8
      y <- 2
      c %()% a %is% c(3,r=4,8)
    }, {
      c %()% a[2:3] %is% c(r=4, 7)
      x <- 2
      c %()% a %is% c(2,r=4,7)
    }, {
      c %()% a["r"] %is% c(r=4)
    }
    )
})

test_that("[<-.... replacement operator can take values from another dotsxp", {
  #should be able to replace items of a dotslist with items from
  #another dotslist. Non-dotslists should error.
  with_setup(
    setup={
      x <- 2; y<-3;
      d <- dots(a=x, b=y, c=x+y)
    }, {
      d[2] <- 10
      y <- 4
      c %()% d %is% c(a=2, b=10, c=6)
    }, {
      d["a"] <- dots(x*y)
      x <- 5
       c %()% d %is% c(a=15, b=3, c=8)
    })
})

test_that("dots [[]] and $ operators force ONE promise and return the value.", {
  with_setup(
    setup={
      x <- 2; y <-3
      d <- dots(a=x, b=y, c=x+y)
    },
    {
      d[[2]] %is% 3
      x <- 1
      d[[1]] %is% 1
    },
    {
      x <- 4
      d$c %is% 7
      x <- 3
      d[["a"]] %is% 3
    }
    )
})

test_that("'expressions' unpacks expressions from a dotslist", {
  d <- dots(1, x=x+1, stop("should not evaluate"))
  expect_equal(expressions(d), alist(1, x=x+1, stop("should not evaluate")))
})

test_that("dots [[<- and $<- inject evaluated promises into a dotslist", {
  #it's impossible to inject unevaluated promises this way; <-
  #forces its RHS. This way is consistent with [[ anyway.
  with_setup(
      setup={
        x <- "x"; y <- 3
        d <- dots(a=x, b=y, c=x+y)
      }, {
        d[[2]] <- x
        x <- 4
        d[[2]] %is% "x"
        #expressions(d)[2] %is% quote(x) #Nope, no.
      }, {
        d$b <- x
        x <- 4
        d$b %is% "x"
        #expressions(d)["b"] %is% quote("x")
      }
  )
})

test_that("dots names method extracts tags without forcing", {
  names(dots(a, b, c=, 4, d=x+y, )) %is% c("", "", "c", "", "d", "")
  names(dots(stop("no"), a=stop("no"))) %is%  c("", "a")
  names(dots()) %is% NULL
})

test_that("dots names<- method can set tags w/o forcing", {
  with_setup(
    setup={
      x <- 2; y<-3;
      d <- dots(a=x, b=y, c=x+y)
    }, {
      names(d) <- c("foo", "bar", "baz")
      y <- 4
      c %()% d %is% c(foo=2, bar=4, baz=6) }
    )
})
