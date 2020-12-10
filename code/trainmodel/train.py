import numpy as np
import pandas as pd
from collections import defaultdict
from collections import Counter
from sklearn.metrics import roc_auc_score   
import joblib
import sklearn.model_selection as sk_model_selection
from sklearn.metrics import confusion_matrix, classification_report
from imblearn.ensemble import EasyEnsembleClassifier
import numpy as np  
import matplotlib.pyplot as plt
from sklearn.utils import shuffle
import math,time
from imblearn.combine import SMOTEENN
from imblearn.under_sampling import RandomUnderSampler
from sklearn.feature_selection import SelectFromModel,SelectKBest,chi2,f_classif,mutual_info_classif,SelectFdr,SelectFpr
import sklearn.model_selection as model_selection
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split,ShuffleSplit,StratifiedKFold,cross_val_score
def fail_rate_diff(new_data):
    count=0
   
    rate_diff=[]
    from decimal import Decimal
    ix=new_data.index
    indexs=list(new_data.index)
    shapes=len(indexs)
    for i in range(shapes):

#         
        if count<=shapes-1:
            if count==0:
                rate_diff.append(0)
            else:
                m=indexs[i]
                n=indexs[i-1]
                if new_data.loc[[n]]['fail_ratio_pr'].values[0]==0 and new_data.loc[[m]]['fail_ratio_pr'].values[0]==0 :
                    rate_diff.append(0)
                elif new_data.loc[[n]]['fail_ratio_pr'].values[0]==0 and new_data.loc[[m]]['fail_ratio_pr'].values[0]>0 :
                    rate_diff.append(100.0)
                elif new_data.loc[[n]]['fail_ratio_pr'].values[0]==0 and new_data.loc[[m]]['fail_ratio_pr'].values[0]<0 :
                    rate_diff.append(-100)
                else:
                    rate_diff.append(100*(new_data.loc[[m]]['fail_ratio_pr'].values[0]-new_data.loc[[n]]['fail_ratio_pr'].values[0])/new_data.loc[[n]]['fail_ratio_pr'].values[0])
        count+=1
    rate_diff=pd.Series(rate_diff,index=ix)
    new_data.insert(31,'fail_ratio_diff',rate_diff)
    return new_data




#================================================

def chi2_feature(X_pass,y_pass,pnum):
        new_features_pass=[]
        flag=0
#         X_pass=X_pass.drop(['fail_ratio_diff','commiter_exp','gaussian_diff'],axis=1)
        if 'fail_ratio_diff'  in list(X_pass.columns.values):
            X_pass=X_pass.drop(['fail_ratio_diff','commiter_exp'],axis=1)
            flag=1
#         X_pass=X_pass.drop(['fail_ratio_diff','commiter_exp'],axis=1)
        selector = SelectKBest(chi2, k=pnum)
        selector.fit(X_pass, y_pass)
                
                # The list of your K best features
        new_features_pass= list(X_pass.columns[selector.get_support(indices=True)])
    #             print(vector_names)
        new_features_pass.append("pr_status")
        if flag==1:
            new_features_pass.append('fail_ratio_diff')
#         new_features_pass.append('gaussian_diff')
#         new_features_pass.append('commiter_exp')
        return new_features_pass
def f_classif_feature(X_pass,y_pass,pnum):
        
        flag=0
        new_features_pass=[]
        if 'fail_ratio_diff'  in list(X_pass.columns.values):
            X_pass=X_pass.drop(['fail_ratio_diff','commiter_exp'],axis=1)
            flag=1

        
        selector = SelectKBest(f_classif, k=pnum)
        selector.fit(X_pass, y_pass)
                
              
        new_features_pass= list(X_pass.columns[selector.get_support(indices=True)])
   
        new_features_pass.append("pr_status")
        if flag==1:
              new_features_pass.append('fail_ratio_diff')
     
        return new_features_pass
def mutual_feature(X_pass,y_pass,pnum):
        new_features_pass=[]
        X_pass=X_pass.drop(['fail_ratio_diff'],axis=1)
        selector = SelectKBest(mutual_info_classif, k=pnum)
        selector.fit(X_pass, y_pass)      
        new_features_pass= list(X_pass.columns[selector.get_support(indices=True)])  
        new_features_pass.append("pr_status")
        new_features_pass.append('fail_ratio_diff')
        return new_features_pass
def selectFpr_feature(X_pass,y_pass,pnum):
        print("===============SelectFpr")
        print('pnum',pnum)
        new_features_pass=[]
        X_pass=X_pass.drop(['fail_ratio_diff'],axis=1)
        selector = SelectFpr(f_classif, alpha=pnum)
        selector.fit(X_pass, y_pass)
        new_features_pass= list(X_pass.columns[selector.get_support(indices=True)]
        new_features_pass.append("pr_status")       
        new_features_pass.append('fail_ratio_diff')
        return new_features_pass
def selectFdr_feature(X_pass,y_pass,pnum):
        print("===============SelectFdr")
        new_features_pass=[]
        X_pass=X_pass.drop(['fail_ratio_diff'],axis=1)
        selector = SelectFdr(f_classif, alpha=pnum)
        selector.fit(X_pass, y_pass)
        new_features_pass= list(X_pass.columns[selector.get_support(indices=True)])
        new_features_pass.append("pr_status")       
        new_features_pass.append('fail_ratio_diff')
        return new_features_pass

def feature_selection(new_data_pass,new_data_fail,sample=0):
            #selctfrom model
            sample_choose={'rus':RandomOverSampler(random_state=None),'smoteen':SMOTEENN(),'smote':SMOTE(),'under':RandomUnderSampler(random_state=None),0:None}
#            
            
            y_pass=new_data_pass['now_label']
            X_pass=new_data_pass.drop(['now_label'],axis=1)
            
            pass_feature_names = list(X_pass.columns.values)
            
            y_fail=new_data_fail['now_label']
            X_fail=new_data_fail.drop(['now_label'],axis=1)
            fail_feature_names=list(X_fail.columns.values)
#            
            sample_way=sample_choose[sample]
#        
            from xgboost import XGBClassifier
            rf0= XGBClassifier() 
            

            clf = rf0.fit(X_pass,y_pass)
            model_2 = SelectFromModel(clf,prefit=True)
#             print("max_f1",max_f1)
           
            mask= model_2.get_support()

            new_features_pass = [] # The list of your K best features

            for bool, feature in zip(mask, pass_feature_names):
                if bool:
                    new_features_pass.append(feature)

                    
            new_features_fail=[]
            rf1= XGBClassifier()
            clf = rf1.fit(X_fail,y_fail)
            model_2 = SelectFromModel(clf,prefit=True,)
            mask= model_2.get_support()
            for bool, feature in zip(mask, fail_feature_names):
                if bool:
                    new_features_fail.append(feature)
                    
            return new_features_pass,new_features_fail          
#============================================
        
def feature_selection2(new_data_pass,new_data_fail,sample=0,choose_pass=0,pnum=0,choose_fail=0,fnum=0):
            #selctfrom model
            sample_choose={'rus':RandomOverSampler(random_state=None),'smoteen':SMOTEENN(),'smote':SMOTE(),'under':RandomUnderSampler(random_state=None),0:None}
            
            y_pass=new_data_pass['now_label']
            X_pass=new_data_pass.drop(['now_label','pr_status'],axis=1)
            
            pass_feature_names = list(X_pass.columns.values)
            
            y_fail=new_data_fail['now_label']
            X_fail=new_data_fail.drop(['now_label','pr_status'],axis=1)
            fail_feature_names=list(X_fail.columns.values)   
            sample_way=sample_choose[sample]
            new_features_pass=[]
            new_features_fail=[]
#=========================pass
            if choose_pass=='chi2':
                new_features_pass=chi2_feature(X_pass,y_pass,pnum)
            elif choose_pass=='f_classif':
                new_features_pass=f_classif_feature(X_pass,y_pass,pnum)
            elif choose_pass=='mutual_info_classif':
                new_features_pass=mutual_feature(X_pass,y_pass,pnum)
            elif choose_pass=='SelectFpr':
                new_features_pass=selectFpr_feature(X_pass,y_pass,pnum)
            elif choose_pass=='SelectMod':
                new_features_pass=selectMod_feature(X_pass,y_pass)
            
            else:
                new_features_pass=selectFdr_feature(X_pass,y_pass,pnum)
#========================fail
            if choose_fail=='chi2':
                new_features_fail=chi2_feature(X_fail,y_fail,fnum)
            elif choose_fail=='f_classif':
                new_features_fail=f_classif_feature(X_fail,y_fail,fnum)
            elif choose_fail=='mutual_info_classif':
                new_features_fail=mutual_feature(X_fail,y_fail,fnum)
            elif choose_fail=='SelectFpr':
                new_features_fail=selectFpr_feature(X_fail,y_fail,fnum)
            else:
                new_features_fail=selectFdr_feature(X_fail,y_fail,fnum)
            
            return new_features_pass,new_features_fail


#model evaluation
from sklearn import preprocessing
from xgboost import XGBClassifier
from sklearn.model_selection import GridSearchCV          

def run(flag=None,select_flag=None,binary_flag=None,repeat_flag=None,sample_flag=None,selcect_pass=None,pnum=0,select_fail=None,fnum=0):
    dicts_origin={'test_0':[],'build_num':[],'file_modified':[],'file_added':[],'file_deleted':[],'line_added':[],'line_deleted':[],'build_slice':[],'slice_mean':[],'slice_medain':[],'slice_sum':[],"infomation":[]}
    dicts_thresh={'ideal_time':[],'ideal_number':[],'saved_time':[],'save_number':[],'fail_time':[],'fail_number':[],'cost_time':[],'cost_number':[]}
    dic_info={}
    feature_importances_pass=defaultdict(list)
    feature_importances_fail=defaultdict(list)
   
    result_tosee=[]
    auc_roc=[]
    
    f10,f11,f1_macro, f1_micro,f1_weighted ,recall0, recall1 ,recall_micro,recall_macro, recall_weighted=[],[],[],[],[],[],[],[],[],[]
    
    precision0=[] 
    precision1=[] 
    precision_macro=[] 
    precision_micro=[] 
    precision_weighted=[]
    file_name=[]
    file_shape=[]
    ratios=[]
    last_pass_pred,last_pass_test=[],[]
    last_fail_pred,last_fail_test=[],[]
    x_pass_now_label_0,x_fail_now_label_0,x_pass_now_label_1,x_fail_now_label_1=[],[],[],[]
    test_last_label_00,test_last_label_01,test_last_label_10,test_last_label_11=[],[],[],[]
    origin_00,origin_01,origin_10,origin_11=[],[],[],[]
    file_list=get_listdir(os.path.join(os.path.abspath('.'),"data/20_projects/"))
    train_data_num,test_data_num,train_time,test_time=[],[],[],[]
    
    for i in range(0,len(file_list)):
            new_data=pd.read_csv(file_list[i],low_memory=False)
            train_start=time.time()
            train_time.append(time.time()-train_start)
            print(file_list_within[i])
            file_name.append(os.path.basename(file_list[i]))
            file_shape.append(new_data.shape[0])
            
            now_build_id=new_data['now_build_id']
            last_build_id=new_data['build_id']
            file_modify_count=new_data[['files_modified','files_added','files_deleted','line_added','line_deleted']]
            noeach_commit=['import_change_count','signature','deletesignature','addsignature','methodbody','addmethodbody','deletemethodbody',
                           'fieldchange','addfieldchange','deletefieldchange','classchange','addclasschange','deleteclasschange','add_import','deleteimport','prev_modified'
           ]
        
            new_data=new_data.drop(noeach_commit,axis=1)
            new_data=fail_rate_diff(new_data)
            detail_info=['addmethod','deletemethod'
            ,'cmt_add_methodcount','eachsignature','eachdeletesignature','eachaddsignature',
            'eachmethodbody','eachaddmethodbody','eachdeletemethodbody']
            new_data["sum_method"]=new_data['addmethod']+new_data['deletemethod']
            new_data["eachsumsignature"]=new_data['eachsignature']+new_data['eachdeletesignature']+new_data['eachaddsignature']
            new_data["eachsummethodbody"]=new_data['eachmethodbody']+new_data['eachaddmethodbody']+new_data['eachdeletemethodbody']
            new_data=new_data.drop(detail_info,axis=1)
            train_start=time.time()
            new_data=new_data.drop(['now_duration','gaussian','pr_test_assert','pr_other_error','now_is_pr'],axis=1)
            print(new_data.shape[1])
            b=new_data[['pr_status','last_label','now_label','id','now_build_id','build_id']]
            new_data=new_data.drop(['pr_status','last_label','now_label','id','now_build_id','build_id'],axis=1)
            ix=new_data.index
            

            feature_names = list(new_data.columns.values)

            min_max_scaler = preprocessing.MinMaxScaler()
            a= min_max_scaler.fit_transform(new_data)
            a=pd.DataFrame(a,columns=feature_names,index=ix)
            new_data=pd.concat([a,b],axis=1)
            print(new_data.shape[0])
            print("now_label",Counter(new_data['now_label']))
            train_time.append(time.time()-train_start)

            feature_names = list(new_data.columns.values)



            new_data_fail=new_data[~new_data['last_label'].isin(["1"])]

            
            if flag==0:
                test_size=math.ceil(new_data_fail.shape[0]/5)
                test_data=new_data.tail(test_size)
                train_data=new_data.drop(index=test_data.index)
                
            else:
                test_size=math.ceil(new_data.shape[0]/5)
                test_data=new_data.tail(test_size)
                train_data=new_data.drop(index=test_data.index)
            from sklearn.preprocessing import StandardScaler

            train_start=time.time()
            new_data_fail=new_data[(new_data.last_label==0)|((new_data.last_label==1)&(new_data.now_label==0) ) ]
     
            new_data_fail=new_data_fail.drop(["now_build_id",'id','build_id'],axis=1)

            new_data_pass=new_data[(new_data.last_label==1)|((new_data.last_label==0)&(new_data.now_label==0) ) ]
            new_data_pass=new_data_pass.drop(['now_build_id','build_id','log_src_files','log_src_files_in','log_test_files',
             'log_test_files_in','pr_compile_error','pr_test_exception','id'],axis=1)
            train_data=train_data.drop(["now_build_id"],axis=1)
            
            X_pass_new=train_data[(train_data.last_label==1)|((train_data.last_label==0)&(train_data.now_label==0) ) ]
            X_fail_new=train_data[(train_data.last_label==0)|((train_data.last_label==1)&(train_data.now_label==0) ) ]
            train_data_num.append(X_pass_new.shape[0]+X_fail_new.shape[0])
            test_data_num.append(test_data.shape[0])
            y_test=test_data['now_label']
            print("test_size",Counter(y_test))
            x_test=test_data.drop(['now_label'],axis=1)
            if select_flag==1:
                new_features_pass,new_features_fail=feature_selection(new_data_pass, new_data_fail,sample_flag)
#                 new_features_pass,new_features_fail=feature_selection(X_pass_new, X_fail_new,sample_flag)
            elif select_flag==2:
                new_features_pass,new_features_fail=feature_selection2(new_data_pass, new_data_fail,sample_flag,selcect_pass,pnum,select_fail,fnum)
            
            elif select_flag==3:
                new_features_pass,new_features_fail=feature_selection_cv(new_data_pass, new_data_fail)
            elif select_flag==4:
                new_features_pass,new_features_fail=feature_selection_thresh(X_pass_new, X_fail_new,test_data)
            else:

                new_features_pass=new_data_pass.drop(['now_label'],axis=1).columns.values
                new_features_fail=new_data_fail.drop(['now_label'],axis=1).columns.values
 
            RF00=XGBClassifier()
            RF11=XGBClassifier()
            y_pass=X_pass_new['now_label']
            X_pass=X_pass_new.drop(['now_label'],axis=1)[new_features_pass]
            x_pass_now_label_0.append(Counter(y_pass)[0])
            x_pass_now_label_1.append(Counter(y_pass)[1])
            print("data_fail_train.shape",X_pass.shape[1])
            y_fail=X_fail_new['now_label']
            X_fail=X_fail_new.drop(['now_label'],axis=1)[new_features_fail]
            print(os.path.basename(file_list[i]),Counter(y_test))
            from sklearn.metrics.scorer import make_scorer,f1_score,recall_score,precision_score
            if sample_flag=='rus':
                print("rus====")
                rus = RandomOverSampler(random_state=None)
                x_train_PASS, y_train_PASS  = rus.fit_sample(X_pass,y_pass)
                x_train_Fail,y_train_Fail=rus.fit_sample(X_fail,y_fail)
            elif sample_flag=='smoteen':
                rus= SMOTEENN()
                x_train_PASS, y_train_PASS  = rus.fit_sample(X_pass,y_pass)
                x_train_Fail,y_train_Fail=rus.fit_sample(X_fail,y_fail)
            elif sample_flag=='smote':
                print("smote====")
                rus=SMOTE()
                x_train_PASS, y_train_PASS  = rus.fit_sample(X_pass,y_pass)
                x_train_Fail,y_train_Fail=rus.fit_sample(X_fail,y_fail)
            elif sample_flag=='under':
                rus=RandomUnderSampler(random_state=None)
                x_train_PASS, y_train_PASS  = rus.fit_sample(X_pass,y_pass)
                x_train_Fail,y_train_Fail=rus.fit_sample(X_fail,y_fail)
            else:

                x_train_PASS, y_train_PASS  = X_pass,y_pass
                x_train_Fail,y_train_Fail=X_fail,y_fail           
           
            RF0=XGBClassifier()
            RF1=XGBClassifier()
            rf_pass=RF1.fit(x_train_PASS,y_train_PASS )
            rf_fail=RF0.fit(x_train_Fail,y_train_Fail)
            train_time.append(time.time()-train_start)
            feature_num=0
            y_pred_collect=[]
            y_last_collect=[]
            predict_proba=[]
            ix=y_test.index
            now_build_id=now_build_id[ix]
            duration_series=duration_series[ix]
            duration_collect=duration_series.values
            last_build_id=last_build_id[ix]
            file_modify_count=file_modify_count.loc[ix]
            dic={}
            count=0                      
            test_start=time.time()
            for number in x_test.index:#fail
                test_line=x_test.loc[[number]]

                if count==0:
                    if test_line['last_label'].values[0]==0:

                        print("new_features_fail",new_features_fail)
                        test_line1=test_line[new_features_fail]
                        print(test_line1.columns.values)
                        y_pred=RF0.predict(test_line1)
                        predict_proba.append(RF0.predict_proba(test_line1)[:,1]) 
                        
                    else:
                        test_line1=test_line[new_features_pass]
                        y_pred=RF1.predict(test_line1)
                        predict_proba.append(RF1.predict_proba(test_line1)[:,1])
                        
                    count+=1
                    y_pred_collect.append(y_pred[0])
                    y_last_collect.append(test_line['last_label'].values[0])

                else:
                    
#                     
                    if test_line['last_label'].values[0]==0:
                        test_line1=test_line[new_features_fail]
                        y_pred=RF0.predict(test_line1)#ndarry
                        predict_proba.append(RF0.predict_proba(test_line1)[:,1])
                        count+=1
                        y_pred_collect.append(y_pred[0])
                        y_last_collect.append(test_line['last_label'].values[0])

                    else:
                        test_line1=test_line[new_features_pass]
                        y_pred=RF1.predict(test_line1)#ndarry
                        predict_proba.append(RF1.predict_proba(test_line1)[:,1])
                        count+=1
                        y_pred_collect.append(y_pred[0])
                        y_last_collect.append(test_line['last_label'].values[0])
            test_time.append(time.time()-test_start)
            dic_info[os.path.basename(file_list[i])]=dic
            ix=y_test.index
            duration_series=duration_series[ix].values
            y_test_collect=y_test.values
            
            result_tosee.append(f1_score(y_test_collect,y_pred_collect,average='weighted'))
            auc_roc.append(roc_auc_score(y_test_collect,predict_proba,average='weighted'))
            for location in range(0,len(y_last_collect)):
                if y_last_collect[location]==1:
                    
                    last_pass_pred.append(y_pred_collect[location])
                    last_pass_test.append(y_test_collect[location])
                else:
                    last_fail_pred.append(y_pred_collect[location])
                    last_fail_test.append(y_test_collect[location])
                    
                    

            dicts_thresh=save_time(y_pred_collect,y_test_collect,x_test,duration_collect,dicts_thresh) 

            if len(f1_score(y_test_collect,y_pred_collect,average=None))==2:
                print(os.path.basename(file_list[i]),"f1_score",f1_score(y_test_collect,y_pred_collect,average=None))

                print('f1_weighted',f1_score(y_test_collect,y_pred_collect,average='weighted'))

                print('precison_weighted',precision_score(y_test_collect,y_pred_collect,average='weighted'))
                f10.append(f1_score(y_test_collect,y_pred_collect,average=None)[0])
                f11.append(f1_score(y_test_collect,y_pred_collect,average=None)[1])

                f1_macro.append(f1_score(y_test_collect,y_pred_collect,average='macro'))
                f1_micro.append(f1_score(y_test_collect,y_pred_collect,average='micro'))
                f1_weighted.append(f1_score(y_test_collect,y_pred_collect,average='weighted'))
                recall0.append(recall_score(y_test_collect,y_pred_collect,average=None)[0])
                recall1.append(recall_score(y_test_collect,y_pred_collect,average=None)[1])
                recall_macro.append(recall_score(y_test_collect,y_pred_collect,average='macro'))
                recall_micro.append(recall_score(y_test_collect,y_pred_collect,average='micro'))
                recall_weighted.append(recall_score(y_test_collect,y_pred_collect,average='weighted'))
                precision0.append(precision_score(y_test_collect,y_pred_collect,average=None)[0])
                precision1.append(precision_score(y_test_collect,y_pred_collect,average=None)[1])
                precision_macro.append(precision_score(y_test_collect,y_pred_collect,average='macro'))
                precision_micro.append(precision_score(y_test_collect,y_pred_collect,average='micro'))
                precision_weighted.append(precision_score(y_test_collect,y_pred_collect,average='weighted'))
                ratios.append([Counter(y_test_collect)[1],Counter(y_test_collect)[0]]) 
                
          
    list_importance_pass=[]
    list_importance_fail=[]

    print(len(f10))
    print(format(np.mean(f10),'.3f'))
    print(format(np.mean(f11),'.3f'))
    print(format(np.mean(f1_macro),'.3f'))
    print(format(np.mean(f1_micro),'.3f'))
    print(format(np.mean(f1_weighted),'.3f'))
    print(format(np.mean(recall0),'.3f'))
    print(format(np.mean(recall1),'.3f'))
    print(format(np.mean(recall_macro),'.3f'))
    print(format(np.mean(recall_micro),'.3f'))
    print(format(np.mean(recall_weighted),'.3f'))

    print(format(np.mean(precision0),'.3f'))
    print(format(np.mean(precision1),'.3f'))
    print(format(np.mean(precision_macro),'.3f'))
    print(format(np.mean(precision_micro),'.3f'))
    print(format(np.mean(precision_weighted),'.3f'))
    print(format(np.mean(ratios),'.3f') )  
    print(ratios) 
    print("auc:",np.mean(auc_roc))
   
    
run(1,2,0,0,0,'f_classif',25,'chi2',30)  

