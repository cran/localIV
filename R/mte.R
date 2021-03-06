#' Fitting a Marginal Treatment Effects (MTE) Model.
#'
#' \code{mte} fits a MTE model using either the semiparametric local instrumental
#' variables (local IV) method or the normal selection model (Heckman, Urzua, Vytlacil 2006).
#' The user supplies a formula for the treatment selection equation, a formula for the
#' outcome equations, and a data frame containing all variables. The function returns an
#' object of class \code{mte}. Observations that contain NA (either in \code{selection} or
#' in \code{outcome}) are removed.
#'
#' \code{mte_localIV} estimates \eqn{\textup{MTE}(x, u)} using the semiparametric local IV method,
#' and \code{mte_normal} estimates \eqn{\textup{MTE}(x, u)} using the normal selection model.
#'
#' @param selection A formula representing the treatment selection equation.
#' @param outcome A formula representing the outcome equations where the left hand side
#'   is the observed outcome and the right hand side includes predictors of both potential
#'   outcomes.
#' @param data A data frame, list, or environment containing the variables
#'   in the model.
#' @param method How to estimate the model: either "\code{localIV}" for the semiparametric local IV
#'   method or "\code{normal}" for the normal selection model.
#' @param bw Bandwidth used for the local polynomial regression in the local IV approach.
#'   Default is 0.25.
#' @param mf_s A model frame for the treatment selection equations returned by
#'   \code{\link[stats]{model.frame}}
#' @param mf_o A model frame for the outcome equations returned by
#'   \code{\link[stats]{model.frame}}
#'
#' @return An object of class \code{mte}.
#'  \item{coefs}{A list of coefficient estimates: \code{gamma} for the treatment selection equation,
#'    \code{beta10} (intercept) and \code{beta1} (slopes) for the baseline outcome
#'     equation, \code{beta20} (intercept) and \code{beta2} (slopes) for the treated outcome equation,
#'     and \code{theta1} and \code{theta2} for the error covariances when \code{method = "normal"}.}
#'  \item{ufun}{A function representing the unobserved component of \eqn{\textup{MTE}(x, u)}.}
#'  \item{ps}{Estimated propensity scores.}
#'  \item{ps_model}{The propensity score model, an object of class \code{\link[stats]{glm}}
#'     if \code{method = "localIV"}, or an object of class \code{\link[sampleSelection]{selection}}
#'     if \code{method = "normal"}.}
#'  \item{mf_s}{The model frame for the treatment selection equation.}
#'  \item{mf_o}{The model frame for the outcome equations.}
#'  \item{complete_row}{A logical vector indicating whether a row is complete (no missing variables) in the
#'    original \code{data}}
#'  \item{call}{The matched call.}
#' @import rlang
#' @import stats
#' @export
#'
#' @examples
#' mod <- mte(selection = d ~ x + z, outcome = y ~ x, data = toydata, bw = 0.25)
#'
#' summary(mod$ps_model)
#' hist(mod$ps)
#'
#' mte_vals <- mte_at(u = seq(0.05, 0.95, 0.1), model = mod)
#' if(require("ggplot2")){
#'   ggplot(mte_vals, aes(x = u, y = value)) +
#'   geom_line(size = 1) +
#'   xlab("Latent Resistance U") +
#'   ylab("Estimates of MTE at Mean Values of X") +
#'   theme_minimal(base_size = 14)
#' }
#'
#' @seealso \code{\link{mte_at}} for evaluating MTE at different values of the latent resistance \eqn{u};
#'   \code{\link{mte_tilde_at}} for evaluating MTE projected onto the propensity score;
#'   \code{\link{ace}} for estimating average causal effects from a fitted \code{mte} object.
#'
#' @references Heckman, James J., Sergio Urzua, and Edward Vytlacil. 2006.
#'   "\href{https://www.mitpressjournals.org/doi/abs/10.1162/rest.88.3.389}{Understanding Instrumental Variables in Models with Essential Heterogeneity.}"
#'   The Review of Economics and Statistics 88:389-432.
#'
mte <- function(selection, outcome, data = NULL, method = c("localIV", "normal"), bw = NULL){

  # matched call
  cl <- match.call()

  # check if `selection` and `outcome` are formulas
  if(!is_formula(selection) || !is_formula(outcome)){
    stop("Both `selection` and `outcome` have to be formulas.")
  }

  # set data to the parent environment if missing
  data <- data %||% caller_env()

  # extract mf_s and mf_o
  mf_s <- model.frame(selection, data, na.action = NULL,
                     drop.unused.levels = TRUE)
  mf_o <- model.frame(outcome, data, na.action = NULL,
                     drop.unused.levels = TRUE)
  complete_row <- (rowSums(is.na(mf_s)) + rowSums(is.na(mf_o)) == 0)
  mf_s <- mf_s[complete_row, , drop = FALSE]
  mf_o <- mf_o[complete_row, , drop = FALSE]

  # call mte_normal or mte_localIV
  method <- match.arg(method)
  if (method == "normal"){
    out <- mte_normal(mf_s, mf_o)
  } else {
    out <- mte_localIV(mf_s, mf_o, bw = bw)
  }

  # output
  out$complete_row <- complete_row
  out$cl <- cl
  out
}





