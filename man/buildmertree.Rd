% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/buildmer.R
\name{buildmertree}
\alias{buildmertree}
\title{Use buildmer to perform stepwise elimination for \emph{the random-effects part} of \code{lmertree()} and \code{glmertree()} models from package \code{glmertree}}
\usage{
buildmertree(formula, data = NULL, family = gaussian(), cl = NULL,
  direction = "order", crit = "LL", include = NULL,
  calc.summary = TRUE, quiet = FALSE, ...)
}
\arguments{
\item{formula}{The model formula for the maximal model you would like to fit, if possible.}

\item{data}{The data to fit the models to.}

\item{cl}{An optional cluster object as returned by function \code{makeCluster()} from package \code{parallel} to use for parallelizing the evaluation of terms. Note that data and other arguments will be searched for in the global environment only, so you should manually set up the cluster's environments using \code{clusterExport()} if necessary.}

\item{direction}{Character string or vector indicating the direction for stepwise elimination; possible options are \code{'order'} (order terms by their contribution to the model), \code{'backward'} (backward elimination), \code{'forward'} (forward elimination, implies \code{order}). The default is the combination \code{c('order','backward')}, to first make sure that the model converges and to then perform backward elimination; other such combinations are perfectly allowed.}

\item{crit}{Character string or vector determining the criterion used to test terms for elimination. Possible options are \code{'LRT'} (likelihood-ratio test; this is the default), \code{'LL'} (use the raw -2 log likelihood), \code{'AIC'} (Akaike Information Criterion), and \code{'BIC'} (Bayesian Information Criterion).}

\item{include}{A character vector of terms that will be kept in the model at all times. These do not need to be specified separately in the \code{formula} argument.}

\item{calc.summary}{Logical indicating whether to also calculate the summary table for the final model after term elimination.}

\item{quiet}{Logical indicating whether to suppress progress messages.}

\item{...}{Additional options to be passed to \code{lmertree()} or \code{glmertree}.}
}
\description{
Use buildmer to perform stepwise elimination for \emph{the random-effects part} of \code{lmertree()} and \code{glmertree()} models from package \code{glmertree}
}
\examples{
library(buildmer)
m <- buildmertree(Reaction ~ 1 | (Days|Subject) | Days,crit='LL',direction='order',
                  data=lme4::sleepstudy)
m <- buildmertree(Reaction ~ 1 | (Days|Subject) | Days,crit='LL',direction='order',
                  data=lme4::sleepstudy,family=Gamma(link=identity))
}
\seealso{
\code{\link[=buildmer]{buildmer()}}
}