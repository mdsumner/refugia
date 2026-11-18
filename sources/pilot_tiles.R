## DEA tiles intersecting the IBRA pilot footprints (see regions/ibra7, PR #3)
pilot_tiles <- rbind(
  data.frame(region = "tasmania", x = c(56, 56, 57, 57, 57, 57, 58, 58, 58, 58, 59, 59, 59, 59, 59, 60, 60, 60, 60),
                                  y = c(25, 26, 22, 23, 24, 25, 21, 22, 23, 24, 21, 22, 23, 24, 26, 22, 23, 24, 25)),
  data.frame(region = "macdonnell", x = c(45, 45, 46, 46, 47, 47, 47, 48, 48, 49, 49, 49),
                                    y = c(44, 45, 44, 45, 44, 45, 46, 45, 46, 44, 45, 46)))
