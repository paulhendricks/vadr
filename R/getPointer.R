#' Passed a list of dots arguments, returns their expressions and, in
#' names, their machine pointers
#'
#' @param ... A varying number of arguments.
#' @return A vector of integers containing pointer values, one per argument.
#' @author Peter Meilstrup
#' @useDynLib ptools
expression_pointers <- function(...) .Call("expression_pointers", get("..."))
