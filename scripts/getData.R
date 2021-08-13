library(magrittr)
devtools::load_all()
#### Function call ####

getData("#ggplot2",
        5000,
        "data/tweets.csv.gz",
        include_rts = FALSE,
        retryonratelimit = TRUE)

