# initial setup

# load packages
library(tidyverse)
library(tidymodels)
library(ggplot2)
library(skimr)

# set seed
set.seed(1234)

# load data
train <- read_csv("data/raw/train.csv")
test <- read_csv("data/raw/test.csv")

# skim for missingness
skim_without_charts(train)

na_sum <- train %>% 
  summarize(sum = sum(is.na(train)))

print(na_sum)

na_sum_test <- test %>% 
  summarize(sum = sum(is.na(test)))

print(na_sum_test)

# distribution of y
train %>%
  mutate(y_category = cut(y, breaks = c(-Inf, 0, Inf), labels = c("0", "1"))) %>%
  ggplot(mapping = aes(x = y_category)) +
  geom_bar(fill = "blue") +
  geom_text(stat = "Count", aes(label = after_stat(count)), vjust = -0.5) +
  labs(x = "Y Outcome", title = "Outcome Variable Distribution")


# split data
data_split <- initial_split(train, prop = 0.75, strata = y)

train_data <- training(data_split)
test_data <- testing(data_split)

# clean data
train$y <- as.factor(train$y)
train_data$y <- as.factor(train_data$y)
train_data <- na.omit(train_data)

# create folds
class_folds <- vfold_cv(train_data, v = 5, repeats = 3, strata = y)

# create kitchen sink recipe
recipe_sink <- recipe(y ~ ., data = train_data) %>% 
  step_nzv(all_predictors()) %>% 
  step_normalize(all_predictors()) %>% 
  step_impute_mean(all_numeric_predictors()) %>% 
  step_corr(all_numeric_predictors())

# lasso variable select
lasso_mod <- logistic_reg(mode = "classification", 
                          penalty = tune(), 
                          mixture = 1) %>% 
  set_engine("glmnet")

lasso_params <- extract_parameter_set_dials(lasso_mod)
lasso_grid <- grid_regular(lasso_params, levels = 5)

lasso_workflow <- workflow() %>% 
  add_model(lasso_mod) %>% 
  add_recipe(recipe_sink)

lasso_tune <- lasso_workflow %>% 
  tune_grid(resamples = class_folds, 
            grid = lasso_grid)

lasso_workflow_final <- lasso_workflow %>% 
  finalize_workflow(select_best(lasso_tune, metric = "roc_auc"))

lasso_fit <- fit(lasso_workflow_final, data = train)

lasso_tidy <- lasso_fit %>% 
  tidy() %>% 
  filter(estimate != 0 & estimate > 1e-10) %>% 
  pull(term)

# lasso recipe
lasso_rec <- recipe(y ~ x014 + x017 + x023 + 
                      x024 + x034 + x050 + x055 + x056 + x071 + 
                      x073 + x079 + x081 + x088 + x091 + x093 + 
                      x117 + x122 + x129 + x153 + x155 + x158 + 
                      x160 + x170 + x178 + x182 + x190 + x196 + 
                      x212 + x215 + x220 + x223 + x232 + x238 + 
                      x242 + x252 + x260 + x263 + x274 + x284 + 
                      x285 + x289 + x290 + x297 + x300 + x308 + 
                      x319 + x337 + x342 + x343 + x345 + x352 + x356 + 
                      x361 + x384 + x387 + x390 + x392 + x398 + x401 + 
                      x410 + x411 + x412 + x416 + x418 + x426 + x429 + 
                      x433 + x449 + x453 + x456 + x462 + x468 + x472 + 
                      x474 + x476 + x478 + x479 + x483 + x488 + x496 + 
                      x506 + x507 + x511 + x513 + x514 + x527 + x531 + 
                      x533 + x534 + x539 + x552 + x553 + x561 + x562 + 
                      x568 + x573 + x574 + x588 + x603 + x614 + x619 + 
                      x626 + x627 + x632 + x642 + x651 + x656 + x664 + 
                      x674 + x675 + x687 + x693 + x724 + x725 + x728 + x730 + 
                      x737 + x746 + x748 + x753 + x759 + x762 + x764, data = train_data) %>% 
  step_nzv(all_predictors()) %>% 
  step_normalize(all_predictors()) %>% 
  step_impute_mean(all_numeric_predictors()) %>% 
  step_corr(all_numeric_predictors())

save(lasso_rec, file = "data/results/lasso_rec.rda")

