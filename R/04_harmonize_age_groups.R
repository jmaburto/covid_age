#.rs.restartR()
rm(list=ls());gc()
source("R/00_Functions.R")
library(pbmcapply)
# prelims to get offsets

inputCounts <- readRDS("Data/inputCounts.rds")
Offsets     <- readRDS("Data/Offsets.rds")

inputCounts <- 
  inputCounts %>% 
  arrange(Country, Region, Measure, Sex, Age)

 iL <- split(inputCounts,
              list(inputCounts$Code,
                   inputCounts$Sex,
                   inputCounts$Measure),
              drop =TRUE)

# different lambdas
# iLout100 <- mclapply(iL, 
#                      harmonize_age_p,
#                      Offsets = Offsets,
#                      N = 5,
#                      OAnew = 100,
#                      lambda = 100,
#                      mc.cores = 6)
      iLout1e5 <- pbmclapply(iL, 
                           harmonize_age_p,
                           Offsets = Offsets,
                           N = 5,
                           OAnew = 100,
                           lambda = 1e5,
                           mc.cores = 6)
# iLout1e6 <- mclapply(iL, 
#                      harmonize_age_p,
#                      Offsets = Offsets,
#                      N = 5,
#                      OAnew = 100,
#                      lambda = 1e6,
#                      mc.cores = 6)
 # make parallel wrapper with everything in try()
 # remove try error elements, then bind and process.
 
# 
#   n   <- lapply(iLout100,function(x){length(x) == 1}) %>% unlist() %>% which()
  (nn  <- lapply(iLout1e5,function(x){length(x) == 1}) %>% unlist() %>% which())
  # nnn <- lapply(iLout1e6,function(x){length(x) == 1}) %>% unlist() %>% which()
  # 
(problem_codes <-  iLout1e5[nn])

      if (length(problem_codes) > 0){
        iLout1e5 <- iLout1e5[-nn]
      }
      
# TR: now include rescale
# outputCounts_5_100 <-
#     iLout100 %>% 
#     #iLout[-n] %>% 
#     bind_rows() %>% 
#     mutate(Value = ifelse(is.nan(Value),0,Value)) %>% 
#     group_by(Code, Measure) %>% 
#     # Newly added
#     do(rescale_sexes_post(chunk = .data)) %>% 
#     ungroup() %>%
#     pivot_wider(names_from = Measure,
#                 values_from = Value) %>% 
#     mutate(date = dmy(Date)) %>% 
#     arrange(Country, Region, date, Sex, Age) %>% 
#     select(-date) 
# iLout <- iLout1e5[-nn]
outputCounts_5_1e5 <-
  iLout1e5 %>% 
  #iLout[-n] %>% 
  bind_rows() %>% 
  mutate(Value = ifelse(is.nan(Value),0,Value)) %>% 
  group_by(Code, Measure) %>% 
  # Newly added
  do(rescale_sexes_post(chunk = .data)) %>% 
  ungroup() %>%
  pivot_wider(names_from = Measure,
              values_from = Value) %>% 
  mutate(date = dmy(Date)) %>% 
  arrange(Country, Region, date, Sex, Age) %>% 
  select(-date) 

# outputCounts_5_1e6 <-
#   iLout1e6 %>% 
#   #iLout[-n] %>% 
#   bind_rows() %>% 
#   mutate(Value = ifelse(is.nan(Value),0,Value)) %>% 
#   group_by(Code, Measure) %>% 
#   # Newly added
#   do(rescale_sexes_post(chunk = .data)) %>% 
#   ungroup() %>%
#   pivot_wider(names_from = Measure,
#               values_from = Value) %>% 
#   mutate(date = dmy(Date)) %>% 
#   arrange(Country, Region, date, Sex, Age) %>% 
#   select(-date) 

# round output for csv
# outputCounts_5_100_rounded <- 
#   outputCounts_5_100 %>% 
#   mutate(Cases = round(Cases,1),
#          Deaths = round(Deaths,1),
#          Tests = round(Tests,1))

outputCounts_5_1e5_rounded <- 
  outputCounts_5_1e5 %>% 
  mutate(Cases = round(Cases,1),
         Deaths = round(Deaths,1),
         Tests = round(Tests,1))

# outputCounts_5_1e6_rounded <- 
#   outputCounts_5_1e6 %>% 
#   mutate(Cases = round(Cases,1),
#          Deaths = round(Deaths,1),
#          Tests = round(Tests,1))

# saveRDS(outputCounts_5_100, "Data/Output_5_100.rds")
saveRDS(outputCounts_5_1e5, "Data/Output_5_1e5.rds")
# saveRDS(outputCounts_5_1e6, "Data/Output_5_1e6.rds")


header_msg <- paste("Counts of Cases, Deaths, and Tests in harmonized 5-year age groups (PCLM lambda = 100000):",timestamp(prefix="",suffix=""))
write_lines(header_msg, path = "Data/Output_5.csv")
write_csv(outputCounts_5_1e5_rounded, path = "Data/Output_5.csv", append = TRUE, col_names = TRUE)

saveRDS(outputCounts_5_1e5, "Data/Output_5.rds")


# Repeat for 10-year age groups
 outputCounts_10 <- 
  outputCounts_5_1e5 %>% 
  mutate(Age = Age - Age %% 10) %>% 
  group_by(Country, Region, Code, Date, Sex, Age) %>% 
  summarize(Cases = sum(Cases),
            Deaths = sum(Deaths),
            Tests = sum(Tests)) %>% 
  ungroup() %>% 
  mutate(AgeInt = ifelse(Age == 100, 5, 10)) 
outputCounts_10 <- outputCounts_10[, colnames(outputCounts_5_1e5)]

# round output for csv
outputCounts_10_rounded <- 
  outputCounts_10 %>% 
  mutate(Cases = round(Cases,1),
         Deaths = round(Deaths,1),
         Tests = round(Tests,1))

header_msg <- paste("Counts of Cases, Deaths, and Tests in harmonized 10-year age groups (PCLM lambda = 100000):",timestamp(prefix="",suffix=""))
write_lines(header_msg, path = "Data/Output_10.csv")
write_csv(outputCounts_10_rounded, path = "Data/Output_10.csv", append = TRUE, col_names = TRUE)
saveRDS(outputCounts_10, "Data/Output_10.rds")


spot_checks <- FALSE
if (spot_checks){
# Once-off diagnostic plot:

ASCFR5 <- 
outputCounts_5_1e5 %>% 
    group_by(Country, Region, Code, Sex) %>% 
    mutate(D = sum(Deaths)) %>% 
    ungroup() %>% 
    mutate(ASCFR = Deaths / Cases,
           ASCFR = na_if(ASCFR, Deaths == 0)) %>% 
    filter(!is.na(ASCFR),
           Sex == "b",
           D >= 100) 
ASCFR5 %>% 
  ggplot(aes(x=Age, y = ASCFR, group = interaction(Country, Region, Code))) + 
  geom_line(alpha=.05) + 
  scale_y_log10() + 
  xlim(20,100) + 
  geom_quantile(ASCFR5,
                mapping=aes(x=Age, y = ASCFR), 
                method = "rqss",
                quantiles=c(.025,.25,.5,.75,.975), 
                lambda = 2,
                inherit.aes = FALSE,
                color = "tomato",
                size = 1)

}

# 
# NYCpop2 <- c(NYCpop[1:85],yhat[86:length(yhat)])
# 
# CC <- inputCounts %>% 
#   filter(Code == "NYC06.04.2020",
#          Measure == "Cases") %>% 
#   pull(Value)
# 
# x <- inputCounts %>% 
#   filter(Code == "NYC06.04.2020",
#          Measure == "Cases") %>% 
#   pull(Age) %>% 
#   as.integer()
# nlast <- 105 - x[length(x)]
# 
# Cx<- pclm(x,CC,nlast=nlast,offset = NYCpop2)$fitted
# Cx <- Cx * NYCpop2
# DD <- inputCounts %>% 
#   filter(Code == "NYC06.04.2020",
#          Measure == "Deaths") %>% 
#   pull(Value)
# 
# #Dx1 <- pclm(x,DD,nlast=nlast,offset = Cx)$fitted
# Dx2 <- pclm(x,DD,nlast=nlast,offset = NYCpop2)$fitted
# 
# plot(0:104, Dx1 * Cx)
# lines(0:104, Dx2 * NYCpop2)

# plot(0:104, NYCpop2)

# step 1: get single age offsets for each country.

do.this <- FALSE
if (do.this){
  CodesToSample <-
  outputCounts_5_100 %>% 
    mutate(Short = paste(Country, 
                         Region,
                         Sex,
                         Date,
                         sep = "-")) %>%
    group_by(Country, Region, Sex, Date) %>% 
    mutate(N = sum(Deaths)) %>% 
    filter(N >= 100) %>% 
    pull(Short) %>% unique()
  
  SpotChecks <- sample(CodesToSample,500,replace=FALSE)
  
  compare_lambdas <- function(Short, X100, X1e5, X1e6){
    X100 <-
      X100 %>% 
      mutate(.Short = paste(Country, 
                           Region,
                           Sex,
                           Date,
                           sep = "-"),
             lambda = 100)
    X1e5 <-
      X1e5 %>% 
      mutate(.Short = paste(Country, 
                           Region,
                           Sex,
                           Date,
                           sep = "-"),
             lambda = 1e5)
    
    X1e6 <-
      X1e6 %>% 
      mutate(.Short = paste(Country, 
                          Region,
                          Sex,
                          Date,
                          sep = "-"),
             lambda = 1e6)
    
    X100       <- X100 %>% filter(.Short == Short)
    X1e5       <- X1e5 %>% filter(.Short == Short)
    X1e6       <- X1e6 %>% filter(.Short == Short)
    DatCompare <- list(X100,X1e5,X1e6) %>% bind_rows()
  
    DatCompare %>% 
      mutate(CFR = Deaths / Cases) %>% 
      ggplot(aes(x=Age, y = CFR, color = as.factor(lambda), group = lambda)) + 
      geom_line()+
      scale_y_log10()+
      ggtitle(Short)
    
    }
  for (i in 26:500){
    cat(i,"\n")
  print(compare_lambdas("Greece-All-b-11.05.2020",
                  outputCounts_5_100,
                  outputCounts_5_1e5,
                  outputCounts_5_1e6))
  Sys.sleep(1.5)
  }
  
}