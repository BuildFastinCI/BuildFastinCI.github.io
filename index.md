## BuildFast: History-Aware Build Outcome Prediction for Fast Feedback and Reduced Cost in Continuous Integration
Long build times in continuous integration (CI) can greatly increase the cost in human and computing resources, and thus become 
a common barrier faced by software organizations adopting CI. Build outcome prediction has been proposed as one of the remedies 
to reduce such cost. However, the state-of-the-art approaches have a poor prediction performance for failed builds, and are not
designed for practical usage scenarios. To address the problems,we first conduct an empirical study on 2,590,917 builds to 
characterize builds times in real world projects, and a survey with 75 developers to understand their perceptions about build 
outcome prediction. Then, motivated by our study and survey results,we propose a newhistory-aware approach,named BuildFast, 
to predict CI build outcomes cost-efficiently and practically. It can help to obtain fast integration feedback and reduce 
integration cost. In particular, we introduce multiple failure-specific features from closely related historical builds via 
analyzing build logs and changed files, and propose an adaptive prediction model to switch between two models based on the build
outcome of the previous build. We also investigate a practical online usage scenario of BuildFast, where builds are predicted in chronological order, and measure the benefit from correct predictions and the cost from incorrect predictions. Our experiments on
20 projects have demonstrated that BuildFast can improve the state-of-the-art approach by 47.5% in F1-score for failed builds.


### Survey
You can get the survey in details in [here](./survey.md).

### Features

#### Features about the Current Build

In this table, for fine-grained feature extractions such as class-, method-, field- and import-level changes,
we use the [ClDiff tool](https://github.com/FudanSELab/CLDIFF)


ID | Feature | Description | Implementation
------------ | ------------- | ------------- | -------------
C1 | src_churn | # of lines of production code changed | use ruby library _Rugged_ to get diff data of two build commit, use string matching to filter the src code
C2 | test_churn | # of lines of test code changed | get test file changes in the diff data of two build commit,use string matching the filter the test code
C3 | src_ast_diff | whether production code is changed in AST | use ClDiff tool 
C4 | test_ast_diff |  whether test code is changed in AST | use ClDiff tool
C5 | line_added | # of added lines in all files | get files changes in the diff data 
C6 | line_deleted | # of deleted lines in all files | get files changes in the diff data
C7 | files_added | # of files added | getfiles changes in the diff data 
C8 | files_deleted | # of files deleted | get files changes in the diff tool
C16 | met_body_modified | # of method bodies modified | use ClDiff tool
C17 | met_changed | # of methods added or deleted | use ClDiff tool
C18 | field_changed | # of fields modified, added or deleted  | use ClDiff tool
C19 | import_changed | # of import statements added or deleted | use ClDiff tool
C20 | class_modified | # of classes modified | use ClDiff tool
C21 | class_added | # of classes added | use ClDiff tool
C22 | class_deleted | # of classes deleted | use ClDiff tool
C23 | met_added | # of methods added |use ClDiff tool
C24 | met_deleted | # of methods deleted | use ClDiff tool
C25 | field_modified | # of fields modified | use ClDiff tool
C26 | field_added | # of fields added | use ClDiff tool
C27 | field_deleted | # of fields deleted | use ClDiff tool
C28 | import_added | # of import statements added | use ClDiff tool
C29 | import_deleted | # of import statements deleted | use ClDiff tool
C30 | commits | # of commits included | search for the current build commit's parent until it is a build commit
C31 | fix_commits | # of bug-fixing commits included | whether the pull request title or commit message include parttern _F[f]ix_
C32 | merge_commits | # of merge commits included | whether the pull request title or commit message include parttern _M[m]erge_
C33 | committers | # of unique committers | the unique commiters of commits mentioned above
C34 | by_core_member | whether a core member triggers the build | committer committed code at least once within the 3 months before this commit
C35 | is_master | whether the build occurs on master branch | get from the build information
C36 | time_interval | time interval since the previous build | time interval between two build time
C37 | day_of_week day | of week when the build starts | ruby library _time_, method _time.day_
C38 | time_of_day | time of day when the build starts | ruby library _time_, method time.hour

#### Features about the Previous Build

ID | Feature | Description | Implementation
------------ | ------------- | ------------- | -------------
P1 | pr_state build state (i.e., passed, errored or failed) | get from the build information
P2 | pr_compile_error |  whether compilation error occurs |  build log include character string _"COMPILATION ERROR "_
P3 | pr_test_exception | whether tests throw exceptions | build log include character string _"Tests in error"_
P4 | pr_tests_ok | # of tests passed | extract from build log 
P5 | pr_tests_fail |  # of tests failed | extract from build log 
P6 | pr_duration | overall time duration of the build | get from build information
P7 | pr_src_churn | # of lines of production code changed | diff information of previous build
P8 | pr_test_churn |  # of lines of test code changed | diff information of previous build

#### Features about Historical Builds

ID | Feature | Description | Implementation
------------ | ------------- | ------------- | -------------
H1 | fail_ratio_pr |  % of broken builds in all the previous builds | # of previous failed builds / # of previous builds
H2 | fail_ratio_pr_inc | increment of fail_ratio_pr at last broken build to fail_ratio_pr at penultimate broken build | increment of fail_ratio_pr
H3 | fail_ratio_re | % of broken builds in recent 5 builds | # of fail builds in recent 5 builds / 5
H4 | fail_ratio_com_pr |  % of broken builds in all the previous builds that were triggered by the current committer | # of failed builds triggered by current committer/ # of all previous builds
H5 | fail_ratio_com_re | % of broken builds in recent 5 builds that were triggered by the current committer | # of failed builds triggered by current committer in recent 5 builds/5
H6 | last_fail_gap | # of builds since the last broken build | search the current build's last build untill the build is broken
H7 | consec_fail_max | maximum of  # of consecutive broken builds | find all the current build's last pass builds(one or more), count the maximum interval
H8 | consec_fail_avg | average of # of consecutive broken builds | find all the current build's last pass builds(one or more), count the average interval
H9 | consec_fail_sum | sum of # of consecutive broken builds | find all the current build's last pass builds(one or more), count the sum of interval
H10 | commits_on_files | # of commits on the files in last 3 months | get information of the changed files of current build, as well as the commits in last 3 months,count the number if these commits's files include the current changed files
H11 | file_fail_prob_max | maximum of the probability of each changed file involved in previous broken builds | count the frequency of each current changed files appeared in the previous broken builds ,then divided by the total num of previous broken builds, find the maximum ratio
H12 | file_fail_prob_avg | average of the probability of each changed file involved in previous broken builds | count the frequency of each current changed files appeared in the previous broken builds ,then divided by the total num of previous broken builds, find average ratio
H13 | file_fail_prob_sum | sum of the probability of each changed file involved in previous broken builds |count the frequency of each current changed files appeared in the previous broken builds ,then divided by the total num of previous broken builds, find the sum ratio
H14 | pr_src_files | # of production files changed between the latest passed build and the previous build | find the lastest pass build of current build, and then get the diff data of lastest pass and previous build, use string matching to filter the src files
H15 | pr_src_files_in | size of the intersection of src_files and pr_src_files | size of the intersection of src_files and pr_src_files
H16 | pr_test_files | # of test files changed between the latest passed build and the previous build | the same as pr_src_files, but filter the test file
H17 | pr_test_files_in | size of the intersection of test_files and pr_test_files | size of the intersection of test_files and pr_test_files
H18 | pr_config_files | # of build script files changed between the latest passed build and the previous build | the same as pr_src_files, but filter the config file
H19 | pr_config_files_in | size of the intersection of config_files and pr_config_files | size of the intersection of config_files and pr_config_files
H20 | pr_doc_files | # of documentation files changed between the latest passed build and the previous build | the same as pr_src_files, but filter the doc file
H21 | pr_doc_files_in | size of the intersection of doc_files and pr_doc_files | size of the intersection of doc_files and pr_doc_files
H22 | log_src_files | # of production files reported in the build log of the previous build | use string matching to filter the src files in the build log 
H23 l|og_src_files_in | size of the intersection of log_src_files and src_files | size of the intersection of log_src_files and src_files
H24 | log_test_files | # of test files reported in the build log of the previous build | use string matching to filter the test files in the build log 
H25 | log_test_files_in | size of the intersection of log_test_files and test_files | size of the intersection of log_test_files and test_files
H26 | team_size | size of team contributing in last 3 months | non-repeat committers that make commit in last 3 months



### Code and Dataset

You can download the code to extract features and train the model on  [github](https://github.com/BuildFastinCI/BuildFastinCI.github.io)


### Feature selections  and different classifiers


#### Use different feature selections 

Evaluation | BuildFast_IG&Chi2 | Select From model | BuildFast_IG | BuildFast_Chi2 | BuildFast_Mutual | BuildFast_Fpr | BuildFast_Fdr
------------ | ------------- | ------------- | -------------  | ------------- | ------------- | ------------- | -------------
f1-fail  |  0.472  |  0.436  |  0.446  |  0.464  |  0.430  |  0.437  |  0.434
f1-pass  |  0.913  |  0.877  |  0.912  |  0.900  |  0.862  |  0.906  |  0.891
f1-macro  |  0.692  |  0.657  |  0.679  |  0.682  |  0.646  |  0.671  |  0.663
f1-micro  |  0.883  |  0.843  |  0.881  |  0.875  |  0.819  |  0.874  |  0.856
f1-weighted  |  0.874  |  0.841  |  0.870  |  0.866  |  0.821  |  0.862  |  0.850
recall-fail  |  0.439  |  0.454  |  0.414  |  0.444  |  0.451  |  0.413  |  0.435
recall-pass  |  0.926  |  0.869  |  0.926  |  0.905  |  0.856  |  0.917  |  0.892
recall-macro  |  0.682  |  0.661  |  0.670  |  0.674  |  0.654  |  0.665  |  0.664
recall-micro  |  0.883  |  0.843  |  0.881  |  0.875  |  0.819  |  0.874  |  0.856
recall_weighted  |  0.883  |  0.843  |  0.881  |  0.875  |  0.819  |  0.874  |  0.856
pre-fail  |  0.572  |  0.506  |  0.541  |  0.546  |  0.498  |  0.566  |  0.528
pre-pass  |  0.902  |  0.901  |  0.900  |  0.902  |  0.890  |  0.900  |  0.899
pre-macro  |  0.737  |  0.703  |  0.720  |  0.724  |  0.694  |  0.733  |  0.714
pre-micro  |  0.883  |  0.843  |  0.881  |  0.875  |  0.819  |  0.874  |  0.856
precision-weighted  |  0.874  |  0.860  |  0.868  |  0.868  |  0.854  |  0.866  |  0.863
auc  |  0.784  |  0.783  |  0.784  |  0.787  |  0.755  |  0.788  |  0.785
benefit  |  2723.000  |  2624.008  |  2700.224  |  2654.035  |  2703.035  |  2663.223  |  2669.579
cost  |  592.000  |  410.181  |  548.578  |  510.746  |  643.953  |  408.812  |  440.902
gain  |  2131.000  |  2213.827  |  2151.646  |  2143.288  |  2059.082  |  2254.411  |  2228.677

> These feature selection methods can be got on [scikit-learn](https://scikit-learn.org/stable/modules/classes.html#module-sklearn.feature_selection)

>**BuildFast_IG&Chi2** is our feature selection approach, we adopted Chi-Squared Testing to select the top 30 features for our first model, and Information Gain to select the top 25 features for our second model. 

>**Select From model** : when training the model, we select features where the features feature importance is larger than the mean feature importances.

>**BuildFast_IG** : we adopted Information Gain to select 30 features and 25 features for the two models respectively.

>**BuildFast_Chi2** : we adopted Chi-Squared Testing to select 30 features and 25 features for the two models respectively.

>**BuildFast_Mutual** : we adopted Mutual information to select 30 features and 25 features for the two models respectively.

>**BuildFast_Fpr** : we  select the pvalues below alpha(0.01) based on a FPR test.

>**BuildFast_Fdr** : we select the p-values for an estimated false discovery rate.

Compared with other approaches, BuildFast_IG&Chi2  improved the precision, recall and F1-score for failed builds by 4% and 2% and 3% in most cases; 
and for other metrics, BuildFast_IG&Chi2 slightly improved 1%-4%. 
We can see that BuildFast_IG&Chi2 get the most stable result for all the metrics compared with other method such as **Select From model** , **BuildFast_Mutual**.
For example, **Select From model** slightly improved the recall-fail by 1.5% but it has a much lower pre-fail, reduced by 6.6%.           For benefit, cost and gain, there was no statistically significant differencedue to the minority of failed builds and the variance of build times. Still, BuildFast_IG&Chi2 had a total gain of 2,131 hours for all projects from
one-fourth of the builds (i.e., testing data) with its benefit exceeding
its cost. Thus, BuildFast is cost-efficiency and can save CI cost.


#### Use different classifier

Evaluation | Xgboost |  Randomforest 
------------ | ------------- | ------------- 
f1-fail  |  0.472  |  0.432
f1-pass  |  0.913  |  0.912
f1-macro  |  0.692  |  0.672
f1-micro  |  0.883  |  0.881
f1-weighted  |  0.874  |  0.867
recall-fail  |  0.439  |  0.385
recall-pass  |  0.926  |  0.935
recall-macro  |  0.682  |  0.660
recall-micro  |  0.883  |  0.881
recall_weighted  |  0.883  |  0.881
pre-fail  |  0.572  |  0.592
pre-pass  |  0.902  |  0.894
pre-macro  |  0.737  |  0.743
pre-micro  |  0.883  |  0.881
precision-weighted  |  0.874  |  0.867
auc  |  0.784  |  0.779
benefit  |  2723.000  |  2825.768
cost  |  592.000  |  613.467
gain  |  2131.000  |  2212.302
 
Compared with **Randomforest** , **Xgboost**  improved the recall and F1-score for failed builds by 5.1% and 4%, thus
**Xgboost** model contributes to the improved recall and F1-score for  failed builds.
