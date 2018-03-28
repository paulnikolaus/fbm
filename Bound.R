# computes the values of the backlog bounds in the reportcd

library("dvfBm")

source("estimate_hurst.R")

# Computes the plain SNC Bound from Theorem 3.5, Equation (3.10)
# (without any statistical operations)
# n = Point in time
# x = backog
# std_dev = standard deviation,
# H = Hurst Parameter
# server_rate = Server Rate, also denoted C in formulas,
# arrival_rate = constant rate from the arrival model, also denoted as \lambda
backlog_bound <- function(n = 10, x = 3.0, std_dev = 0.5, H = 0.75,
                         server_rate = 1.0, arrival_rate = 0.6) {
  if (server_rate <= arrival_rate) {
    stop("server rate has to be greater than the arrival rate")
  }

  k <- 1:n
  exponent <- -(x + (server_rate - arrival_rate) * k) ** 2 / (
    2 * (std_dev ** 2) * k ** (2 * H))
  backlog <- sum(exp(exponent))

  return(backlog)
}

# Computes the statistical backlog bound based on the FGN increments
# (Statistical version of theorem 3.1)
# n = Point in Time
# x = Backlog
# std_dev = standard deviation
# server_rate = Server Rate, also denoted C
# arrival_rate = constant arrival rate, also denoted \lambda
# conflevel = confidence level of estimation

stat_backlog_bound <- function(FGNincrements, n = 10, x = 3.0, std_dev = 1.0,
                               server_rate = 1.0, arrival_rate = 0.6,
                               conflevel = 0.95) {
  if (server_rate < arrival_rate) {
    stop("The server rate has to be greater than the arrival rate")
  }

  N <- length(FGNincrements)

  h_estimated <- estimate_hurst(FGNincrements, arrival_rate, std_dev)
  H_up <- conf_level_hurst(N, h_estimated, conflevel)

  backlog_prob <- 1 - conflevel + backlog_bound(
    n = n, x = x, std_dev = std_dev, H = H_up,
    server_rate = server_rate, arrival_rate = arrival_rate)

  return(backlog_prob)
}

# Binary search for sufficient backlog value x s.t. P(q(n) > x) <= p,
# last parameter indicates whether SNC or stat_nc bound should be used
# n = Point in time
# p = violation probability
# std_dev = standard deviation
# H = Hurst parameter
# server_rate = Server Rate, also known as C in formulas
# arrival_rate = constant rate from the arrival model, also denoted \lambda
# splits = number of iterations for binary search
# conflevel = confidence level if estimation was used
# traffic = input arrival traffic (only necessary for statnc bound)
inverse_bound <- function(n = 10, p = 10  **  (-2), std_dev = 0.5, H = 0.7,
                          server_rate = 1.0, arrival_rate = 0.6, splits = 10,
                          conflevel = 0.95, traffic,
                          estimate_traffic = FALSE) {
  backlog <- 0.5
  difference <- 1
  its <- 0

  # Search for the backlog value where bound <= p holds for the first time,
  # bisect from there

  if (estimate_traffic) {
    probbound <- stat_backlog_bound(
      FGNincrements = traffic, n = n, x = backlog, std_dev = std_dev,
      server_rate = server_rate, arrival_rate = arrival_rate,
      conflevel = conflevel)
  } else {
    probbound <- backlog_bound(
      n = n, x = backlog, std_dev = std_dev, H = H, server_rate = server_rate,
      arrival_rate = arrival_rate)
  }
  while (probbound > p) {
    difference <- backlog
    backlog <- 2 * backlog
    if (estimate_traffic) {
      probbound <- stat_backlog_bound(
        FGNincrements = traffic, n = n, x = backlog, std_dev = std_dev,
        server_rate = server_rate, arrival_rate = arrival_rate,
        conflevel = conflevel)
    } else {
      probbound <- backlog_bound(n = n, x = backlog, std_dev = std_dev, H = H,
                                server_rate = server_rate,
                                arrival_rate = arrival_rate)
    }

  }
  difference <- difference / 2
  backlog <- backlog - difference
  # Bisect $splits times
  while (its < splits) {
    if (estimate_traffic) {
      probbound <- stat_backlog_bound(
        FGNincrements = traffic, n = n, x = backlog, std_dev = std_dev,
        server_rate = server_rate, arrival_rate = arrival_rate,
        conflevel = conflevel)
    } else {
      probbound <- backlog_bound(
        n = n, x = backlog, std_dev = std_dev, H = H,
        server_rate = server_rate, arrival_rate = arrival_rate)
    }
  # If the bound is smaller -> continue with "left" half, else "right"
    if (probbound <= p ) {
      difference <- difference / 2
      backlog <- backlog - difference
    } else {
      difference <- difference / 2
      backlog <- backlog + difference
    }
    its <- its + 1
  }
  return(max(0, backlog))
}