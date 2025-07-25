\name{allFit}
\alias{allFit}
\alias{plot.allFit}
\alias{summary.allFit}
\alias{plot.fixef.allFit}
\title{Refit a fitted model with all available optimizers}
\usage{
allFit(object, meth.tab = NULL, data=NULL,
       verbose = TRUE,
       show.meth.tab = FALSE,
       maxfun = 1e5,
       parallel = c("no", "multicore", "snow"),
       ncpus = getOption("allFit.ncpus", 1L), cl = NULL,
       catch.errs = TRUE)

\method{plot}{fixef.allFit}(x,
                             shared_y_axis_limits = TRUE,
                             multiply_y_axis_limits = 1,
                             decimal_points = NULL,
                             select_predictors = NULL,
                             nrow = NULL,
                             y_title = 'Fixed effect',
                             y_title_hjust = NULL,
                             number_optimizers = TRUE,
                             interaction_symbol_x = TRUE, ...)
}
\arguments{
  \item{object, x}{a fitted \code{merMod} model (for \code{allFit}) or an \code{allFit} object (for the methods).}
  \item{meth.tab}{a matrix (or data.frame) with columns
    \describe{
      \item{method}{the name of a specific optimization method to pass
	to the optimizer (leave blank for built-in optimizers)}
      \item{optimizer}{the \code{optimizer} function to use}
    }
  }
  \item{data}{data to be included with result (for later debugging etc.)}
  \item{verbose}{logical: report progress in detail?}
  \item{show.meth.tab}{logical: return table of methods?}
  \item{maxfun}{passed as part of \code{optCtrl} to set the maximum
    number of function evaluations: this is \emph{automatically}
    converted to the correct specification (e.g. \code{maxfun},
    \code{maxfeval}, \code{maxit}, etc.) for each optimizer}
  \item{parallel}{The type of parallel operation to be used (if any).
    If missing, the
    default is taken from the option \code{"boot.parallel"} (and if that
    is not set, \code{"no"}).}
  \item{ncpus}{integer: number of processes to be used in parallel operation:
  typically one would choose this to be the number of available CPUs.
  Use \code{options(allFit.ncpus=X)} to set the default value to \code{X}
  for the duration of an R session.}
  \item{cl}{An optional \pkg{parallel} or \pkg{snow} cluster for use if
    \code{parallel = "snow"}.  If not supplied, a cluster on the
    local machine is created for the duration of the \code{boot} call.}
  \item{catch.errs}{(logical) Wrap model fits in \code{tryCatch} clause
    to skip over errors? (\code{catch.errs=FALSE} is probably only
    useful for debugging)}
  \item{shared_y_axis_limits}{(logical) use the same Y axis limits in all plots?}
  \item{multiply_y_axis_limits}{(numeric) expand Y axis limits by a factor (only available if \code{shared_y_axis_limits = TRUE}).}
  \item{decimal_points}{(integer) number of decimal points to display.}
  \item{select_predictors}{(character) vector of predictor names to plot.}
  \item{nrow}{(integer) number of rows in the plot layout.}
  \item{y_title}{(character) Y axis title.}
  \item{y_title_hjust}{(numeric) horizontal justification of the Y axis title.}
  \item{number_optimizers}{(logical) add a number to the names of optimizers?}
  \item{interaction_symbol_x}{(logical) replace colon in interaction terms with a multiplication symbol?}
  \item{...}{additional arguments passed to methods}
}
\value{
  an object of type \code{allFit}, which is a list of fitted \code{merMod} objects (unless \code{show.meth.tab} is
  specified, in which case a data frame of methods is returned). The
  \code{summary} method for this class
  extracts tables with a variety of useful information
  about the different fits (see examples).
}
\description{
   Attempt to re-fit a [g]lmer model with a range of optimizers.
The default is to use all known optimizers for R that satisfy the
requirements (i.e. they do not require functions and allow
box constraints: see \sQuote{optimizer} in \code{\link{lmerControl}}).
These optimizers fall in four categories; (i) built-in
(minqa::bobyqa, lme4::Nelder_Mead, nlminbwrap), (ii) wrapped via optimx
(most of optimx's optimizers that allow box constraints require
an explicit gradient function to be specified; the two provided
here are the base R functions that can be accessed via optimx),
(iii) wrapped via nloptr (see examples for the list of options),
(iv) \sQuote{dfoptim::nmkb} (via the (unexported) \code{nmkbw} wrapper:
this appears as \sQuote{nmkbw} in \code{meth.tab})
}
\details{
\itemize{
\item Needs packages \code{optimx}, and \code{dfoptim} to use all optimizers
\item If you are using \code{parallel="snow"} (e.g. when running in
parallel on Windows), you will need to set up a cluster yourself and run
\code{clusterEvalQ(cl,library("lme4"))} before calling
\code{allFit} to make sure that the
\code{lme4} package is loaded on all of the workers
\item Control arguments in \code{control$optCtrl} that are unused by a particular optimizer will be \emph{silently} ignored (in particular, the \code{maxfun} specification is only respected by \code{bobyqa}, \code{Nelder_Mead}, and \code{nmkbw})
\item Because \code{allFit} works by calling \code{update}, it may be fragile if the original model call contains references to variables, especially if they were originally defined in other environments or no longer exist when \code{allFit} is called.
}
}
\seealso{\code{slice},\code{slice2D} from the \CRANpkg{bbmle} package}
\examples{
if (interactive()) {
library(lme4)
  gm1 <- glmer(cbind(incidence, size - incidence) ~ period + (1 | herd),
             data = cbpp, family = binomial)
  ## show available methods
  allFit(show.meth.tab=TRUE) 
  gm_all <- allFit(gm1)
  ss <- summary(gm_all)
  ss$which.OK            ## logical vector: which optimizers worked?
  ## the other components only contain values for the optimizers that worked
  ss$llik                ## vector of log-likelihoods
  ss$fixef               ## table of fixed effects
  ss$sdcor               ## table of random effect SDs and correlations
  ss$theta               ## table of random effects parameters, Cholesky scale
  plot(gm_all)
  plot.fixef.allFit(gm_all)
} %% interactive()
\dontrun{
  ## Parallel examples for Windows
  nc <- detectCores()-1
  optCls <- makeCluster(nc, type = "SOCK")
  clusterEvalQ(optCls,library("lme4"))
  ### not necessary here because using a built-in
  ## data set, but in general you should clusterExport() your data
  clusterExport(optCls, "cbpp")
  system.time(af1 <- allFit(m0, parallel = 'snow', 
                          ncpus = nc, cl=optCls))
  stopCluster(optCls)
} %% dontrun
} %% examples
\keyword{models}
