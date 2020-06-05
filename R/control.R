#' Set control options for buildmer
#' 
#' \code{buildmerControl()} provides all the knobs and levers that can be manipulated during the buildmer fitting and \code{summary()}/\code{anova()} process. Some of these are part of buildmer's core functionality---for instance, \code{crit} allows to specify different elimination criteria, a core buildmer feature---whereas some are only meant for internal usage, e.g.~\code{I_KNOW_WHAT_I_AM_DOING} is only used to turn off the PQL safeguards in \code{buildbam()}/\code{buildgam()}, which you really should only do if you have a very good reason to believe that the PQL check is being triggered erroneously for your problem.
#' 
#' With the default options, all \code{buildmer} functions will do two things:
#' \enumerate{
#' \item Determine the order of the effects in your model, based on their importance as measured by the likelihood-ratio test statistic. This identifies the `maximal model', which is the model containing either all effects specified by the user, or subset of those effects that still allow the model to converge, ordered such that the most information-rich effects have made it in.
#' \item Perform backward stepwise elimination based on the significance of the change in log-likelihood.
#' }
#' The final model is returned in the \code{model} slot of the returned \code{buildmer} object.
#' All functions in the \code{buildmer} package are aware of the distinction between (f)REML and ML, and know to divide chi-square \emph{p}-values by 2 when comparing models differing only in random effects (see Pinheiro & Bates 2000).
#' The steps executed above can be changed using the \code{direction} argument, allowing for arbitrary chains of, for instance, forward-backward-forward stepwise elimination (although using more than one elimination method on the same data is not recommended). The criterion for determining the importance of terms in the ordering stage and the elimination of terms in the elimination stage can also be changed, using the \code{crit} argument.
#' 
#' @param formula The model formula for the maximal model you would like to fit. Alternatively, a buildmer term list as obtained from \code{\link{tabulate.formula}}. In the latter formulation, you also need to specify a \code{dep='...'} argument specifying the dependent variable to go along with the term list. See \code{\link{tabulate.formula}} for an example of where this is useful
#' @param data The data to fit the model(s) to
#' @param family The error distribution to use
#' @param cl Specifies a cluster to use for parallelizing the evaluation of terms. This can be an object as returned by function \code{makeCluster} from package \code{parallel}, or a whole number to let buildmer create, manage, and destroy a cluster for you with the specified number of parallel processes. Note that, if and only if using the \code{cl} functionality, the data and other arguments will be searched for in the global environment only, so you should manually set up the cluster's environments using \code{clusterExport()} if necessary. In addition, some buildmer-internal objects will be exported to the cluster nodes. These will be cleaned up afterwards, but any already-present objects with the same name (e.g. `\code{p}' will be overwritten)
#' @param direction Character string or vector indicating the direction for stepwise elimination; possible options are \code{'order'} (order terms by their contribution to the model), \code{'backward'} (backward elimination), \code{'forward'} (forward elimination, implies \code{order}). The default is the combination \code{c('order','backward')}, to first make sure that the model converges and to then perform backward elimination; other such combinations are perfectly allowed
#' @param crit Character string or vector determining the criterion used to test terms for elimination. Possible options are \code{'LRT'} (likelihood-ratio test based on chi-square mixtures per Stram & Lee 1994 for random effects; this is the default), \code{'LL'} (use the raw -2 log likelihood), \code{'AIC'} (Akaike Information Criterion), \code{'BIC'} (Bayesian Information Criterion), and \code{'deviance'} (explained deviance -- note that this is not a formal test)
#' @param include A one-sided formula or character vector of terms that will be kept in the model at all times. These do not need to be specified separately in the \code{formula} argument. Useful for e.g. passing correlation structures in \code{glmmTMB} models
#' @param calc.anova Logical indicating whether to also calculate the ANOVA table for the final model after term elimination
#' @param calc.summary Logical indicating whether to also calculate the summary table for the final model after term elimination
#' 
#' @details
#' 
#' There are two hidden arguments that \code{buildmer} can recognize. These are not part of the formal parameters of the various build* functions, but are recognized by all of them to benefit certain specialist applications:
#' \enumerate{
#' \item \code{dep}: It is possible to pass the maximal model formula as a buildmer terms object as obtained via \code{\link{tabulate.formula}}. This allows more control over, for instance, which model terms should always be evaluated together. If the \code{formula} argument is recognized to be such an object (i.e.\ a data frame), then buildmer will use the string specified in the \code{dep} argument as the dependent variable.
#' \item \code{REML}: In some situations, the user may want to force REML on or off, rather than using buildmer's autodetection. If \code{REML=TRUE} (or more precisely, if \code{isTRUE(REML)} evaluates to true), then buildmer will always use REML. This results in invalid results if formal model-comparison criteria are used with models differing in fixed effects (and the user is not guarded against this), but is useful with the 'deviance-explained' criterion, where it is actually the default (you can disable this and use the 'normal' REML/ML-differentiating behavior by passing \code{REML=NA}).
#' }
#' These arguments are not passed on to the fitting function via the \code{...} mechanism.

buildmerControl <- function (
	formula=stop('No formula specified'),
	data=NULL,
	family=gaussian(),
	direction=c('order','backward'),
	cl=NULL,
	crit='LRT',
	elim='LRT',
	fit=stop('No fitting function specified'),
	include=NULL,
	ddf='Wald',
	calc.anova=FALSE,
	calc.summary=TRUE,
	dep=NULL,
	can.use.reml=TRUE,
	force.reml=FALSE,
	tol.grad=formals(converged)$tol.grad,
	tol.hess=formals(converged)$tol.hess,
	I_KNOW_WHAT_I_AM_DOING=FALSE,
	...
) {
	match.call()[-1]
}

buildmer.prep <- function (mc,add,banned) {
	# Check arguments
	ctl <- buildmerControl()
	add <- intersect(names(mc),formals(buildmerControl))
	notok <- intersect(add,banned)
	if (length(notok)) {
		if (length(notok) > 1) {
			stop('Arguments ',notok,' are not available for ',mc[[1]])
		}
		stop('Argument ',notok,' is not available for ',mc[[1]])
	}

	# Separate buildmer arguments and fitter arguments; also handle the presence of an explicit buildmerControl
	ctl[add] <- mc[add]
	if ('buildmerControl' %in% names(mc)) {
		mc[names(mc$buildmerControl)] <- mc$buildmerControl
		mc$buildmerControl <- NULL
	}
	dots <- mc[-add]

	# We now need to actually evaluate all of these terms, in case we will later be running on a cluster and these objects aren't available
	e <- parent.env(2)
	p <- lapply(ctl,eval,e)
	p$dots <- lapply(dots,eval,e)
	p$env <- e
	p$names <- ctl

	# Further processing necessary for buildmer
	if (is.character(p$family)) {
		p$family <- get(p$family,p$env)
	}
	if (is.function(p$family)) {
		p$family <- p$family()
	}
	p$is.gaussian <- p$family$family == 'gaussian' && p$family$link == 'identity'
	p$I_KNOW_WHAT_I_AM_DOING <- isTRUE(p$I_KNOW_WHAT_I_AM_DOING)
	if (!is.function(p$crit)) {
		p$crit <- get(paste0('crit.',p$crit)) #no env, because we want it from buildmer's namespace (or user-defined, which is on the search path by default at this moment)
	}
	if (!is.function(p$elim)) {
		p$elim <- get(paste0('elim.',p$elim))
	}

	p
