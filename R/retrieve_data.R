#' Get and update Tweet dataset
#'
#' @param hashtag The hashtag the tweets must have.
#' @param n The number of tweets to gather.
#' @param filename The filename to write the contents to.
#' @param appname The name of the App
#'    as described in (\url{https://developer.twitter.com/en/portal/projects-and-apps}).
#'    This is required for authentication.
#' @param ... Any other parameters to pass to rtweet::search_tweets
#'
#' @return
#' @export
#' @importFrom magrittr %>%
#' @examples
getData <- function(hashtag, n, filename, ...) {
  logger::log_threshold(logger::INFO)

  logger::log_info("Loading API keys and previous data")

  try(dotenv::load_dot_env(), silent = TRUE)

  secrets <-
    Sys.getenv(c(
      "TWITTER_KEY",
      "TWITTER_SECRET",
      "ACCESS_TOKEN",
      "ACCESS_SECRET"
    ))

  token <- rtweet::create_token(
    consumer_key = secrets["TWITTER_KEY"],
    consumer_secret = secrets["TWITTER_SECRET"],
    access_token = secrets["ACCESS_TOKEN"],
    access_secret = secrets["ACCESS_SECRET"]
  )

  logger::log_info("Getting latest tweets for {hashtag}")

  latest_3000 <- rtweet::search_tweets(hashtag,
                                       n = n, ...) %>%
    rtweet::flatten()

  if (file.exists(filename)) {
    coltypes <-
      c(
        created_at = "T",
        favorite_count = "i",
        retweet_count = "i",
        status_id = "c",
        display_text_width = "d",
        is_quote = "l",
        is_retweet = "l",
        quoted_favorite_count = "i",
        quoted_followers_count = "i",
        quoted_statuses_count = "i",
        followers_count = "i",
        listed_count = "i",
        favourites_count = "i",
        verified = "l",
        quoted_retweet_count = "i",
        quoted_friends_count = "i",
        protected = "l",
        friends_count = "i",
        statuses_count = "i",
        account_created_at = "c"
      )

    current_tweet_data <-
      vroom::vroom(filename, col_types = coltypes)

    all_data <- current_tweet_data %>%
      dplyr::mutate(
        created_at = lubridate::as_datetime(created_at),
        quoted_created_at = lubridate::as_datetime(quoted_created_at),
        account_created_at = lubridate::as_datetime(account_created_at)
      ) %>%
      dplyr::bind_rows(latest_3000) %>%
      clean_data(.)

  } else {

    all_data <- latest_3000 %>%
      dplyr::mutate(
        created_at = lubridate::as_datetime(created_at),
        quoted_created_at = lubridate::as_datetime(quoted_created_at),
        account_created_at = lubridate::as_datetime(account_created_at)
      ) %>%
      clean_data(.)

  }

  logger::log_info("Updating dataset")

  all_data <- prepend_ids(rtweet::flatten(all_data))

  vroom::vroom_write(all_data,
                     filename,
                     delim = ",", quote = "all")

}

clean_data <- function(dataset) {
  unprepend_ids(rtweet::flatten(dataset)) %>%
    # TODO: Improve this.
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      ~ dplyr::na_if(., stringr::str_match_all(., "[NA NA]+"))
    )) %>%
    dplyr::group_by(status_id) %>%
    dplyr::filter(dplyr::row_number(dplyr::desc(favorite_count)) == 1) %>%
    dplyr::ungroup()
}

# Functions from the rtweet package to clean IDs
#License: MIT
#YEAR: 2016
#COPYRIGHT HOLDER: Michael W. Kearney
prepend_ids <- function(x) {
  ids <- grepl("\\_id$", names(x))
  x[ids] <- lapply(x[ids], x_ids)
  x
}

x_ids <- function(x) {
  if (is.recursive(x)) {
    x <- lapply(x, function(.)
      ifelse(
        length(.) == 0 || (length(.) == 1 && is.na(.)),
        list(NA_character_),
        list(paste0("x", .))
      ))
    x <- lapply(x, unlist, recursive = FALSE)
  } else {
    x[x == ""] <- NA_character_
    x[!is.na(x)] <- paste0("x", x[!is.na(x)])
    x[!is.na(x)] <- gsub(" ", " x", x[!is.na(x)])
  }
  x
}

readData <- function(filename) {
  data <- vroom::vroom(filename)

  unprepend_ids(rtweet::flatten(data))

}

unprepend_ids <- function(x) {
  ids <- grepl("\\_id$", names(x))
  x[ids] <- lapply(x[ids], unx_ids)
  x
}

unx_ids <- function(x) {
  if (is.recursive(x)) {
    x <- lapply(x, function(.)
      ifelse(length(.) == 0 || (length(.) == 1 && is.na(.)),
             list(NA_character_), list(gsub("x", "", .))))
    x <- lapply(x, unlist, recursive = FALSE)
  } else {
    x <- gsub("x", "", x)
  }
  x
}
