stopifnot(require("testthat"))
library(lme4) ## make sure package is attached
##  (as.function.merMod() assumes it)
data("Dyestuff", package = "lme4")

## use old (<=3.5.2) sample() algorithm if necessary
if ("sample.kind" %in% names(formals(RNGkind))) {
    suppressWarnings(RNGkind("Mersenne-Twister", "Inversion", "Rounding"))
}

context("fitting lmer models")
## is "Nelder_Mead" default optimizer? -- no longer
(isNM <- formals(lmerControl)$optimizer == "Nelder_Mead")

test_that("lmer", {
    set.seed(101)
    d <- data.frame(z=rnorm(200),
                    f=factor(sample(1:10,200, replace=TRUE)))

    ## Using 'method=*' defunct in 2019-05 (after 6 years of deprecation)
    ## expect_warning(lmer(z~ 1|f, d, method="abc"),"Use the REML argument")
    ## expect_warning(lmer(z~ 1|f, d, method="Laplace"),"Use the REML argument")
    ##sp No '...' anymore
    ##sp expect_warning(lmer(z~ 1|f, d, sparseX=TRUE),"has no effect at present")
    expect_error(lmer(z~ 1|f, ddd), "bad 'data': object 'ddd' not found")
    expect_error(lmer(z~ 1|f), "object 'z' not found")
    expect_error(lmer(z~ 1|f, d[,1:1000]), "bad 'data': undefined columns selected")
    expect_is(fm1 <- lmer(Yield ~ 1|Batch, Dyestuff), "lmerMod")
    expect_is(fm1_noCD <- update(fm1,control=lmerControl(calc.derivs=FALSE)),
              "lmerMod")
    expect_equal(VarCorr(fm1),VarCorr(fm1_noCD))
    ## backward compatibility version {for optimizer="Nelder-Mead" only}:
    if(isNM) expect_is(fm1.old <- update(fm1,control=lmerControl(use.last.params=TRUE)),
                                "lmerMod")
    expect_is(fm1@resp,				"lmerResp")
    expect_is(fm1@pp, 				"merPredD")
    expect_that(fe1 <- fixef(fm1),                      is_equivalent_to(1527.5))
    expect_that(VarCorr(fm1)[[1]][1,1], ## "bobyqa" : 1764.050060
		equals(1764.0375195, tolerance = 1e-5))
    ## back-compatibility ...
    if(isNM) expect_that(VarCorr(fm1.old)[[1]][1,1], equals(1764.0726543))

    expect_that(isREML(fm1),                            equals(TRUE))
    expect_is(REMLfun <- as.function(fm1),	"function")
    expect_that(REMLfun(1),                             equals(319.792389042002))
    expect_that(REMLfun(0),                             equals(326.023232155879))
    expect_that(family(fm1),                            equals(gaussian()))
    expect_that(isREML(fm1ML <- refitML(fm1)),          equals(FALSE))
    expect_that(REMLcrit(fm1),                		equals(319.654276842342))
    expect_that(deviance(fm1ML),                        equals(327.327059881135))
    ##						"bobyqa":      49.51009984775
    expect_that(sigma(fm1),                             equals(49.5101272946856, tolerance=1e-6))
    if(isNM) expect_that(sigma(fm1.old),		equals(49.5100503990048))
    expect_that(sigma(fm1ML),                           equals(49.5100999308089))
    expect_that(extractAIC(fm1),                        equals(c(3, 333.327059881135)))
    expect_that(extractAIC(fm1ML),                      equals(c(3, 333.327059881135)))
    ##						"bobyqa":      375.71667627943
    expect_that(vcov(fm1)    [1,1],			equals(375.714676744, tolerance=1e-5))
    if(isNM) expect_that(vcov(fm1.old)[1,1],		equals(375.72027872986))
    expect_that(vcov(fm1ML)  [1,1],			equals(313.09721874266, tolerance=1e-7))
					#		   was 313.0972246957
    expect_is(fm2 <- refit(fm1, Dyestuff2$Yield), "lmerMod")
    expect_that(fixef(fm2),                             is_equivalent_to(5.6656))
    expect_that(VarCorr(fm2)[[1]][1,1],                 is_equivalent_to(0))
    expect_that(getME(fm2, "theta"),                    is_equivalent_to(0))
    expect_that(X  <- getME(fm1, "X"),                  is_equivalent_to(array(1, c(1, 30))))
    expect_is(Zt <- getME(fm1, "Zt"),		"dgCMatrix")
    expect_that(dim(Zt),                                equals(c(6L, 30L)))
    expect_that(Zt@x,                                   equals(rep.int(1, 30L)))
    expect_equal(dimnames(Zt),
                  list(levels(Dyestuff$Batch),
                       rownames(Dyestuff)))
    ##						"bobyqa":      0.8483237982
    expect_that(theta <- getME(fm1, "theta"),           equals(0.84832031, tolerance=6e-6, check.attributes=FALSE))
    if(isNM) expect_that(getME(fm1.old, "theta"),	is_equivalent_to(0.848330078))
    expect_is(Lambdat <- getME(fm1, "Lambdat"), "dgCMatrix")
    expect_that(as(Lambdat, "matrix"),                  is_equivalent_to(diag(theta, 6L, 6L)))
    expect_is(fm3 <- lmer(Reaction ~ Days + (1|Subject) + (0+Days|Subject), sleepstudy),
              					"lmerMod")
    expect_that(getME(fm3,"n_rtrms"),                   equals(2L))
    expect_that(getME(fm3,"n_rfacs"),                   equals(1L))

    expect_equal(getME(fm3, "lower"), c(`Subject.(Intercept)` = 0, Subject.Days = 0))

    expect_error(fm4 <- lmer(Reaction ~ Days + (1|Subject),
                            subset(sleepstudy,Subject==levels(Subject)[1])), "must have > 1")
    expect_warning(fm4 <- lFormula(Reaction ~ Days + (1|Subject),
                             subset(sleepstudy,Subject==levels(Subject)[1]),
                             control=lmerControl(check.nlev.gtr.1="warning")), "must have > 1")
    expect_warning(fm4 <- lmer(Reaction ~ Days + (1|Subject),
                            subset(sleepstudy,Subject %in% levels(Subject)[1:4]),
                               control=lmerControl(check.nlev.gtreq.5="warning")),
                   "< 5 sampled levels")
    sstudy9 <- subset(sleepstudy, Days == 1 | Days == 9)
    expect_error(lmer(Reaction ~ 1 + Days + (1 + Days | Subject),
                        data = sleepstudy, subset = (Days == 1 | Days == 9)),
                   "number of observations \\(=36\\) <= number of random effects \\(=36\\)")
    expect_error(lFormula(Reaction ~ 1 + Days + (1 + Days | Subject),
                           data = sleepstudy, subset = (Days == 1 | Days == 9)),
                 "number of observations \\(=36\\) <= number of random effects \\(=36\\)")
    ## with most recent Matrix (1.1-1), should *not* flag this
    ## for insufficient rank
    dat <- readRDS(system.file("testdata", "rankMatrix.rds", package="lme4"))
    expect_is(lFormula(y ~ (1|sample) + (1|day) + (1|day:sample) +
                           (1|operator) + (1|day:operator) + (1|sample:operator) +
                           (1|day:sample:operator),
                       data = dat,
                       control = lmerControl(check.nobs.vs.rankZ = "stop")),
                       "list")
    ## check scale
    ss <- within(sleepstudy, Days <- Days*1e6)
    expect_warning(lmer(Reaction ~ Days + (1|Subject), data=ss),
                 "predictor variables are on very different scales")

    ## Promote warning to error so that warnings or errors will stop the test:
    options(warn=2)
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, REML=TRUE), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, start=NULL), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, verbose=0L), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, subset=TRUE), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, weights=rep(1,nrow(Dyestuff))), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, na.action="na.exclude"), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, offset=rep(0,nrow(Dyestuff))), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, contrasts=NULL), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, devFunOnly=FALSE), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, control=lmerControl(optimizer="Nelder_Mead")), "lmerMod")
    expect_is(lmer(Yield ~ 1|Batch, Dyestuff, control=lmerControl()), "lmerMod")
    ## avoid _R_CHECK_LENGTH_1_LOGIC2_ errors ...
    if (getRversion() < "3.6.0" || (requireNamespace("optimx", quietly = TRUE) &&
                                    packageVersion("optimx") > "2018.7.10")) {
        expect_error(lmer(Yield ~ 1|Batch, Dyestuff, control=lmerControl(optimizer="optimx")),"must specify")
        expect_is(lmer(Yield ~ 1|Batch, Dyestuff,
                       control=lmerControl(optimizer="optimx",
                                           optCtrl=list(method="L-BFGS-B"))),
                  "lmerMod")
    }
    expect_error(lmer(Yield ~ 1|Batch, Dyestuff, control=lmerControl(optimizer="junk")),
                 "couldn't find optimizer function")
    ## disable test ... should be no warning
    expect_is(lmer(Reaction ~ 1 + Days + (1 + Days | Subject),
                   data = sleepstudy, subset = (Days == 1 | Days == 9),
                   control=lmerControl(check.nobs.vs.rankZ="ignore",
                   check.nobs.vs.nRE="ignore",
                   check.conv.hess="ignore",
                   ## need to ignore relative gradient check too;
                   ## surface is flat so *relative* gradient gets large
                   check.conv.grad="ignore")),
              "merMod")
    expect_is(lmer(Reaction ~ 1 + Days + (1|obs),
                   data = transform(sleepstudy,obs=seq(nrow(sleepstudy))),
                   control=lmerControl(check.nobs.vs.nlev="ignore",
                   check.nobs.vs.nRE="ignore",
                   check.nobs.vs.rankZ="ignore")),
              "merMod")
    expect_error(lmer(Reaction ~ 1 + Days + (1|obs),
                      data = transform(sleepstudy,obs=seq(nrow(sleepstudy))),
                      "number of levels of each grouping factor"))

    ## check for errors with illegal input checking options
    flags <- lme4:::.get.checkingOpts(names(formals(lmerControl)))
    .t <- lapply(flags, function(OPT) {
	## set each to invalid string:
	## cat(OPT,"\n")
	expect_error(lFormula(Reaction~1+Days+(1|Subject), data = sleepstudy,
			      control = do.call(lmerControl,
				  ## Deliberate: fake typo
				  ##		       vvv
				  setNames(list("warnign"), OPT))),
		     "invalid control level")
    })
    ## disable warning via options
    options(lmerControl=list(check.nobs.vs.rankZ="ignore",check.nobs.vs.nRE="ignore"))
    expect_is(fm4 <- lmer(Reaction ~ Days + (1|Subject),
			  subset(sleepstudy,Subject %in% levels(Subject)[1:4])), "merMod")
    expect_is(lmer(Reaction ~ 1 + Days + (1 + Days | Subject),
                   data = sleepstudy, subset = (Days == 1 | Days == 9),
                   control=lmerControl(check.conv.hess="ignore",
                   check.conv.grad="ignore")),
              "merMod")
    options(lmerControl=NULL)
    ## check for when ignored options are set
    options(lmerControl=list(junk=1,check.conv.grad="ignore"))
    expect_warning(lmer(Reaction ~ Days + (1|Subject),sleepstudy),
                   "some options")
    options(lmerControl=NULL)
    options(warn=0)
    expect_error(lmer(Yield ~ 1|Batch, Dyestuff, junkArg=TRUE), "unused argument")
    expect_warning(lmer(Yield ~ 1|Batch, Dyestuff, control=list()),
                    "passing control as list is deprecated")
    if(FALSE) ## Hadley broke this
        expect_warning(lmer(Yield ~ 1|Batch, Dyestuff, control=glmerControl()),
                       "passing control as list is deprecated")

    ss <- transform(sleepstudy,obs=factor(seq(nrow(sleepstudy))))
    expect_warning(lmer(Reaction ~ 1 + (1|obs), data=ss,
         control=lmerControl(check.nobs.vs.nlev="warning",
                             check.nobs.vs.nRE="ignore")),
                   "number of levels of each grouping factor")

    ## test deparsing of very long terms inside mkReTrms
    set.seed(101)
    longNames <- sapply(letters[1:25],
                        function(x) paste(rep(x,8),collapse=""))
    tstdat <- data.frame(Y=rnorm(10),
                         F=factor(1:10),
                         matrix(runif(250),ncol=25,
                                dimnames=list(NULL,
                                longNames)))
    expect_is(lFormula(Y~1+(aaaaaaaa+bbbbbbbb+cccccccc+dddddddd+
                        eeeeeeee+ffffffff+gggggggg+hhhhhhhh+
                        iiiiiiii+jjjjjjjj+kkkkkkkk+llllllll|F),
                   data=tstdat,
                   control=lmerControl(check.nobs.vs.nlev="ignore",
                   check.nobs.vs.nRE="ignore",
                   check.nobs.vs.rankZ="ignore")),"list")

    ## do.call(new,...) bug
    new <- "foo"
    expect_is(refit(fm1),"merMod")
    rm("new")

    ## test subset-with-( printing from summary
    fm1 <- lmer(z~1|f,d,subset=(z<1e9))
    expect_equal(sum(grepl("Subset: \\(",capture.output(summary(fm1)))),1)

    ## test messed-up Hessian
    fm1 <- lmer(z~ as.numeric(f) + 1|f, d)
    fm1@optinfo$derivs$Hessian[2,2] <- NA
    expect_warning(lme4:::checkConv(fm1@optinfo$derivs,
                     coefs=c(1,1),
                     ctrl=lmerControl()$checkConv,lbound=0),
                   "Problem with Hessian check")

    ## test ordering of Ztlist names
    ## this is a silly model, just using it for a case
    ## where nlevs(RE term 1) < nlevs(RE term 2)x
    data(cbpp)
    cbpp <- transform(cbpp,obs=factor(1:nrow(cbpp)))
    fm0 <- lmer(incidence~1+(1|herd)+(1|obs),cbpp,
         control=lmerControl(check.nobs.vs.nlev="ignore",
                             check.nobs.vs.rankZ="ignore",
                             check.nobs.vs.nRE="ignore",
                             check.conv.grad="ignore",
                             check.conv.singular="ignore",
                             check.conv.hess="ignore"))
    fm0B <- update(fm0, .~1+(1|obs)+(1|herd))
    expect_equal(names(getME(fm0,"Ztlist")),
                 c("obs.(Intercept)", "herd.(Intercept)"))
    ## stable regardless of order in formula
    expect_equal(getME(fm0,"Ztlist"),getME(fm0B,"Ztlist"))
    ## no optimization  (GH #408)
    fm_noopt <- lmer(z~1|f,d,
                     control=lmerControl(optimizer=NULL))
    expect_equal(unname(unlist(getME(fm_noopt,c("theta","beta")))),
                 c(0.244179074357121, -0.0336616441209862))
    expect_error(lmer(z~1|f,d,
                     control=lmerControl(optimizer="none")),
                 "deprecated use")
    my_opt <- function(fn,par,lower,upper,control) {
        opt <- optim(fn=fn,par=par,lower=lower,
              upper=upper,control=control,,method="L-BFGS-B")
        return(list(par=opt$par,fval=opt$value,conv=opt$convergence))
    }
    expect_is(fm_noopt <- lmer(z~1|f,d,
                     control=lmerControl(optimizer=my_opt)),"merMod")

    ## test verbose option for nloptwrap
    cc <- capture.output(lmer(Reaction~1+(1|Subject),
         data=sleepstudy,
         control=lmerControl(optimizer="nloptwrap",
                 optCtrl=list(xtol_abs=1e-6, ftol_abs=1e-6)),
         verbose=5))
    expect_equal(sum(grepl("^iteration:",cc)),14)

}) ## test_that(..)

test_that("coef_lmer", {
    ## test coefficient extraction in the case where RE contain
    ## terms that are missing from the FE ...
    set.seed(101)
    d <- data.frame(resp=runif(100),
                    var1=factor(sample(1:5,size=100,replace=TRUE)),
                    var2=runif(100),
                    var3=factor(sample(1:5,size=100,replace=TRUE)))
    library(lme4)
    mix1 <- lmer(resp ~ 0 + var1 + var1:var2 + (1|var3), data=d)
    c1 <- coef(mix1)
    expect_is(c1, "coef.mer")
    cd1 <- c1$var3
    expect_is   (cd1, "data.frame")
    n1 <- paste0("var1", 1:5)
    nn <- c(n1, paste(n1, "var2", sep=":"))
    expect_identical(names(cd1), c("(Intercept)", nn))
    expect_equal(fixef(mix1),
                 setNames(c(0.2703951, 0.3832911, 0.451279, 0.6528842, 0.6109819,
                            0.4949802, 0.1222705, 0.08702069, -0.2856431, -0.01596725),
                          nn), tolerance= 6e-6)# 64-bit:  6.73e-9
})

test_that("getCall", {
    ## GH #535
    getClass <- function() "foo"
    expect_is(glmer(round(Reaction) ~ 1 + (1|Subject), sleepstudy,
        family=poisson), "glmerMod")
    rm(getClass)
})

test_that("better info about optimizer convergence",
{
    set.seed(14)
    cbpp$var <- rnorm(nrow(cbpp), 10, 10)

    suppressWarnings(gm2 <-
                         glmer(cbind(incidence, size - incidence) ~ period * var + (1 | herd),
                               data = cbpp, family = binomial,
                               control=glmerControl(optimizer=c("bobyqa","Nelder_Mead")))
                     )

    ## FIXME: with new update, suppressWarnings(update(gm2)) will give
    ## Error in as.list.environment(X[[i]], ...) :
    ## promise already under evaluation: recursive default argument reference or earlier problems?
    op <- options(warn=-1)
    gm3 <- update(gm2,
                  control=glmerControl(optimizer="bobyqa",
                                       optCtrl=list(maxfun=2)))
    options(op)

    cc <-capture.output(print(summary(gm2)))
    expect_equal(tail(cc,3)[1],
                 "optimizer (Nelder_Mead) convergence code: 0 (OK)")
})

context("convergence warnings etc.")

fm1 <- lmer(Reaction~ Days + (Days|Subject), sleepstudy)
suppressMessages(fm0 <- lmer(Reaction~ Days + (Days|Subject), sleepstudy[1:20,]))

msg_in_output <- function(x, str) {
    cc <- capture.output(.prt.warn(x))
    any(grepl(str , cc))
}

test_that("convergence warnings from limited evals", {
    expect_warning(fm1B <- update(fm1, control=lmerControl(optCtrl=list(maxeval=3))),
                   "convergence code 5")
    expect_true(msg_in_output(fm1B@optinfo, "convergence code: 5"))
    expect_warning(fm1C <- update(fm1, control=lmerControl(optimizer="bobyqa",optCtrl=list(maxfun=3))),
                   "maximum number of function evaluations exceeded")
    expect_true(msg_in_output(fm1C@optinfo,
                              "maximum number of function evaluations exceeded"))
    ## one extra (spurious) warning here ...
    expect_warning(fm1D <- update(fm1, control=lmerControl(optimizer="Nelder_Mead",optCtrl=list(maxfun=3))),
                   "failure to converge in 3 evaluations")
    expect_true(msg_in_output(fm1D@optinfo,
                              "failure to converge in 3 evaluations"))
    expect_message(fm0D <- update(fm0, control=lmerControl(optimizer="Nelder_Mead",calc.derivs=FALSE)),
                   "boundary")
    expect_true(msg_in_output(fm0D@optinfo,
                              "(OK)"))
})

## GH 533
test_that("test for zero non-NA cases", {
    data_bad <- sleepstudy
    data_bad$Days <- NA_real_
    expect_error(lmer(Reaction ~ Days + (1| Subject), data_bad),
                 "0 \\(non-NA\\) cases")
})

##
test_that("catch matrix-valued responses in lmer/glmer but not in formulas", {
    dd <- data.frame(x = rnorm(1000), batch = factor(rep(1:20, each=50)))
    dd$y <- matrix(rnorm(1e4), ncol = 10)
    dd$y2 <- matrix(rpois(1e4, lambda = 1), ncol = 10)
    expect_error(lmer(y ~ x + (1|batch), dd), "matrix-valued")
    fr <- lFormula(y ~ x + (1|batch), dd)$fr
    expect_true(is.matrix(model.response(fr)))
    expect_error(glmer(y ~ x + (1|batch), dd, family = poisson), "matrix-valued")
    fr <- glFormula(y ~ x + (1|batch), dd, family = poisson)$fr
})

test_that("catch matrix-valued responses", {
    dd <- data.frame(x = rnorm(1000), batch = factor(rep(1:20, each=50)))
    dd$y <- matrix(rnorm(1e4), ncol = 10)
    expect_error(lmer(y ~ x + (1|batch), dd), "matrix-valued")
})

test_that("update works as expected", {
	m <- lmer(Reaction ~ Days + (Days || Subject), sleepstudy)
	expect_equivalent(fitted(update(m, .~.-(0 + Days | Subject))),
                          fitted(lmer(Reaction ~ Days + (1|Subject), sleepstudy)))
})
