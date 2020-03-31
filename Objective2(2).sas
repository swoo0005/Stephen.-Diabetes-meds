

libname DIABETES 'G:\Stephen Wood analysis\Results file';
libname ANALYSIS 'G:\Stephen Wood analysis\Working data for diabetes dynamics';



**SECTION 1: COLLECTING ALL USERS OF ANY A10 MEDICATION B/W 1/7/13-30/4/16;

***SELECT all diabetes drug dispensings, including insulin;
data diabetes.diab_drugs;
set 'G:\PBS_ Original_data_one big data set\pbs_extract_eo2015_1_148';
where substr(ATC_LVL_5_CD,1,3)='A10';
run;

 **Restrict to appropriate dates;
data diabetes.diab_drugs_1;
set diabetes.diab_drugs;
if  spply_dt < '01jul12'd then delete; /**deleting all supplies prior to july 2012 and after June 2018**/
if  spply_dt > '30jun18'd then delete;
if  spply_dt < '01jul13'd then prioruse=1;   /**marking ppl who had been using diab meds prior to jul 2013**/
run;

*dropping unnecessary columns and changing to variable names that I am more familiar with;
data diabetes.diab_drugs_2 (drop=benefit pharm_state pat_cat script_type prscrb_dt athrty_cd);
set diabetes.diab_drugs_1;
ATC5=ATC_LVL_5_CD;
format supp_date date9.;
supp_date=spply_dt;
run;

*Sorting by patient id and by supply date;
proc sort data=diabetes.diab_drugs_2 nodupkey out=diabetes.diab_drugs_3;
by ppn supp_date ATC5;
run;


data diabetes.diab_drugs_4;
set  diabetes.diab_drugs_3;
by ppn; /*making it group by patient id*/
if first.ppn & supp_date>= '01Jul2013'd then incident_use1 = 1;   *if the first record for a person is on or after the 01 Jul 2013, then it is incident use;
prev_use_priorJul2013 = lag(prioruse);  /*variable is equal to the prioruse value of line before*/
if first.ppn then prev_use_priorJul2013 =.; /*equal to missing if first line of person*/
if prioruse =1 then prev_use_priorJul2013 = .; /*equal to missing if supp date is before Jul2013*/
date_prioruse = lag(supp_date); /*making a variable that is equal to the supply date of previous line*/
if first.ppn then date_prioruse =.; /*missing for first line of person*/
format date_prioruse date9.; /*formatting as date*/
time_prioruse = supp_date - date_prioruse;  /*making a variable for the time between this supply
                                             and the previous supply*/
if first.ppn then time_prioruse =.;  /*missing for the first line of a person*/

*adding in incident use if there is more than a year gap between the first supply after
Jul 2013, and the last supply before Jul 2013;
if prev_use_priorJul2013 = 1 & time_prioruse > 365 then incident_use2 = 1;
     /*if the prior use was more than 1 year ago, then it is incident use*/
if incident_use1 = 1 | incident_use2 = 1 then incident_use=1; /*joining the two ways of defining
 incident use together*/
run;
*255467 incident users of an A10 med;
proc freq;
tables incident_use incident_use1 incident_use2; 
run;

*so far, this code as marked the first supply after 2013 for all people whose incident supply is after
2013. Now we need to limit the dataset to all the records for these invidiuals, after and including 
the index supply. ;
data diabetes.diab_drugs_5;
set diabetes.diab_drugs_4;
retain incident_user; 
by ppn;
if first.ppn then incident_user = incident_use; /*each time there is a new patient id, 
                                                    this resets incident_user to the value
                                                    of incident_use*/
if incident_use = 1 then incident_user = incident_use;  /*if a later record in a person id marks the
                                                   incident use, then that line and all following
                                                    lines for that person will have incident_user=1*/
run;


data diabetes.diab_drugs_6;
set diabetes.diab_drugs_5;
if incident_user ne 1 then delete;  
if supp_date<'01JUL2013'd then delete;                                      
run;

*setting up an index date for each individual;
data   diabetes.diab_drugs_7;
set  diabetes.diab_drugs_6;
if first.ppn then indexdate=supp_date;
format indexdate date9.;
retain indexdate;
by ppn;
run;

**looking at drug(s) given on index date;
data diabetes.diab_drugs_8 ; 
set diabetes.diab_drugs_7; 
where indexdate=supp_date;
run;
	

/**now going to categorise everyone based on what T2DM med(s) they started on.
First I need to find all T2DM meds which were supplied on the index day for each patient**/
data diabetes.diab_drugs_9;
set diabetes.diab_drugs_8;
if substr(ATC5,1,5)='A10BA' then start_class=1;/**metformin**/
if substr(ATC5,1,5)='A10BB' then start_class=2;/**SUs**/
if substr(ATC5,1,5)='A10BD' then start_class=3; /**metformin-combos**/
if substr(ATC5,1,5)='A10BF' then start_class=4; /**acarbose**/
if substr(ATC5,1,5)='A10BG' then start_class=5;/**TZD**/
if substr(ATC5,1,5)='A10BH' then start_class=6;/**DPP4**/
if substr(ATC5,1,5)='A10BJ' then start_class=7;/**glp1**/
if substr(ATC5,1,5)='A10BK' then start_class=8;/**sglt2 (dapa and empa)**/
if substr(ATC5,1,5)='A10BX' then start_class=8;/**canagliflozin**/
if substr(ATC5,1,4)='A10A' then start_class=9; /**insulins**/
run;





*** Check allocation;
proc freq data=diabetes.diab_drugs_9;
tables start_class; 
run;


data diabetes.start_class (keep=ppn start_class indexdate);
set diabetes.diab_drugs_9;
run;

*first identifying all who started in insulin-will delete them later;
data diabetes.insulin (keep=ppn insulin_user);
set diabetes.diab_drugs_9;
if start_class=9 then insulin_user=1;
if insulin_user=1 then output;
run;

proc sort data=diabetes.insulin nodupkey out=diabetes.insulin_nodup;
by ppn ;
run;

**deleting insulin initiators;
data diabetes.cohort_no_insulin_inits; 
merge diabetes.diab_drugs_7 (in=a) diabetes.insulin_nodup (in=b);
by ppn;
if a; 
if insulin_user=1 then delete;
run;

proc sort data=diabetes.cohort_no_insulin_inits nodupkey out=aaa;
by ppn ;
run;
**205,473 ppl remain in cohort;


**looking at initial combination users;
data diabetes.combo_users;
set diabetes.cohort_no_insulin_inits; 
if substr(ATC5,1,5)='A10BA' then start_class=1;/**metformin**/
if substr(ATC5,1,5)='A10BB' then start_class=2;/**SUs**/
if substr(ATC5,1,5)='A10BD' then start_class=3; /**metformin-combos**/
if substr(ATC5,1,5)='A10BF' then start_class=4; /**acarbose**/
if substr(ATC5,1,5)='A10BG' then start_class=5;/**TZD**/
if substr(ATC5,1,5)='A10BH' then start_class=6;/**DPP4**/
if substr(ATC5,1,5)='A10BJ' then start_class=7;/**glp1**/
if substr(ATC5,1,5)='A10BK' then start_class=8;/**sglt2 (dapa and empa)**/
if substr(ATC5,1,5)='A10BX' then start_class=8;/**canagliflozin**/
if substr(ATC5,1,4)='A10A' then start_class=9; /**insulins**/
if supp_date=indexdate then output;
run;




*now looking at all individual meds products given on index date. If > 1 then delete the person because this is a combination initiator;
proc sort data= diabetes.combo_users nodupkey out=diabetes.combo_users; 
by ppn start_class;
run; 


*Counting up number of meds given on index date using arrays;
*** Dimension all Comorbidity choices and initialise to 0;
data diabetes.combo_users_1;
set diabetes.combo_users;
array cm[9] (9*0);  
run;
*** Set appropriate comorb group to 1 for each record;
data diabetes.combo_users_2;
array cm[9];
set diabetes.combo_users_1;
cm[start_class]=1;  
run;
data diabetes.combo_users_3;
set diabetes.combo_users_2;
by ppn;
array cm[*] cm1-cm9;
array sm[*] sm1-sm9;
retain sm1-sm9;
if first.ppn=1 then do i=1 to 9;
sm[i]=cm[i];
end;
sm[start_class]=1;
if last.ppn=1 then output;
run;
data  diabetes.combo_users_4;
array sm{*} sm1-sm9;
set diabetes.combo_users_3;
Tot=0;
do i=1 to 9;
if sm{i}=1 then
do;
Tot=Tot+1;
end;
end;
output;
run;
data  diabetes.combo_users_5 (keep= ppn combo);
set diabetes.combo_users_4;
if Tot>1 then combo=1;
if combo=1 then output;
run;

**deleting combination Tx initiators;
data diabetes.cohort_no_ins_or_combos; 
merge diabetes.cohort_no_insulin_inits(in=a) diabetes.combo_users_5 (in=b);
by ppn;
if a; 
if combo=1 then delete;
run;
**196798 ppl remain after deletion of combo users;



data diabetes.cohort_no_ins_or_combos_2;
set diabetes.cohort_no_ins_or_combos; 
if substr(ATC5,1,5)='A10BA' then start_class=1;/**metformin**/
if substr(ATC5,1,5)='A10BB' then start_class=2;/**SUs**/
if substr(ATC5,1,5)='A10BD' then start_class=3; /**metformin-combos**/
if substr(ATC5,1,5)='A10BF' then start_class=4; /**acarbose**/
if substr(ATC5,1,5)='A10BG' then start_class=5;/**TZD**/
if substr(ATC5,1,5)='A10BH' then start_class=6;/**DPP4**/
if substr(ATC5,1,5)='A10BJ' then start_class=7;/**glp1**/
if substr(ATC5,1,5)='A10BK' then start_class=8;/**sglt2 (dapa and empa)**/
if substr(ATC5,1,5)='A10BX' then start_class=8;/**canagliflozin**/
if substr(ATC5,1,4)='A10A' then start_class=9; /**insulins**/
if supp_date=indexdate then output;
run;

proc sort data=diabetes.cohort_no_ins_or_combos_2 nodupkey out=diabetes.cohort_no_ins_or_combos_2;
by ppn start_class;
run;

**now there are 196798 lines in total (one line for each remaining initiator) which makes sense as ppl who started on >1 product were deleted;
proc freq data=diabetes.cohort_no_ins_or_combos_2;
tables start_class; 
run;

**Now to pull out just the metformin and SU initiators;

data diabetes.met_SU_initiators (keep=ppn start_class indexdate); 
set diabetes.cohort_no_ins_or_combos_2; 
if start_class=1 or start_class=2 then output;
run;

**sorting NDSS data by ppn so it can be merged with the PBS data;
proc sort data='G:\Stephen Wood analysis\original NDSS data\ndss_cohort.sas7bdat' out=diabetes.NDSS_sorted;
by ppn;
run;


**Merging back just the metformin/SU initiators with the original list of A10 meds and with the NDSS data;
data diabetes.met_SU_initiators_1; 
merge diabetes.met_SU_initiators(in=a) diabetes.diab_drugs_3 (in=b) diabetes.NDSS_sorted (in=c) ;
by ppn;
if a; 
run;

proc contents data=diabetes.NDSS_sorted;
run;

**selecting only people diagnoserd with T2DM;
data diabetes.met_SU_initiators_2;
set diabetes.met_SU_initiators_1; 
if diab_type_new ne '2' then delete;
run;

**getting rid of irrelevant variables;
data diabetes.met_SU_initiators_3 (drop=age_at_death_ndi age_diab_dx age_diab_dx_cat age_dx_reg age_dx_reg_cat age_esrd age_ndss_reg_cat anz_reg_date anz_reg_year anzdata_flag
anzdata_paid_list aria_anz biopsy birthmonth_anz birthyear_anz causdeth control_flag country country_at_dx country_of_birth date_of_last_purchase  death_2013 
deaths_part1 deaths_part2 deaths_part1_1 deaths_part1_2 deaths_part1_3 deaths_part1_4 deaths_part1_5 deaths_part1_6 deaths_part1_7 
deaths_part1_8 deaths_part1_9 deaths_part1_10 deaths_part1_11 deaths_part1_12 deaths_part1_13 deaths_part1_14 
deaths_part2_1 deaths_part2_2 deaths_part2_3 deaths_part2_4 deaths_part2_5 deaths_part2_6 deaths_part2_7 
deaths_part2_8 deaths_part2_9 diabetes_type disease dobmonth_ndi dobyear_ndi dodmonth_ndi dodyear_ndi donage donsex donsourc egfr_ckdepi esrd_2013 first_dialtype
first_dryweight fullweight_anz graftno height height_ndss indigenous_status last_dialdate_anz ndi_fullweight ndi_match_applied ndi_match_probability ndi_pmid_list
ndss_flag ndss_pnid_list ndss_reg_year ndss_status othercauses paid pmid pri_renal_dis pri_renal_dis_cat race_anz seifa_adv_anz seifa_adv_disadv_anz sercreat sex_anz
state_at_dx status_reason_code time_since_dx txdate_anz underlying_cod weight weight_ndss date_first_non_insulin_inject date_insulin_injection_ndss death_date deathyear
insulin_flag insulin_type_injection insulin_type_pump possible_link_iss_flag sex_ndi state_of_registration time_insu_inj age_ndss_reg bmi deathmonth ATC_LVL_5_CD
BNFT_AMT CTG_BNFT_AMT CTG_CD DRG_TYP_CD PHRMCY_APPRVL_TYP_CD PHRMCY_PSTCD PTNT_CNTRBTN_AMT PTNT_PSTCD SPPLY_DT UNDR_CPRSCRPTN_TYP_CD
);
set diabetes.met_SU_initiators_2; 
run;
**151,347 ppl with T2DM in cohort;

proc contents data=diabetes.met_SU_initiators_3;
run;

*keeping a record of which class of medication is dispensed to each individual after their index date;
data diabetes.met_SU_initiators_4;
set diabetes.met_SU_initiators_3;
if substr(ATC5,1,5)='A10BA' then class=1;/**metformin**/
if substr(ATC5,1,5)='A10BB' then class=2;/**SUs**/
if substr(ATC5,1,5)='A10BD' then class=3; /**metformin-combos**/
if substr(ATC5,1,5)='A10BF' then class=4; /**acarbose**/
if substr(ATC5,1,5)='A10BG' then class=5;/**TZD**/
if substr(ATC5,1,5)='A10BH' then class=6;/**DPP4**/
if substr(ATC5,1,5)='A10BJ' then class=7;/**glp1**/
if substr(ATC5,1,5)='A10BK' then class=8;/**sglt2 (dapa and empa)**/
if substr(ATC5,1,5)='A10BX' then class=8;/**canagliflozin**/
if substr(ATC5,1,4)='A10A' then class=9; /**insulins**/
run;

*checking to make sure that nobody had a record of dying prior to the initiation date;
data diabetes.met_SU_initiators_5;
set diabetes.met_SU_initiators_4;
if '.'< ndi_dod < indexdate then delete;
run;
proc sort data=diabetes.met_SU_initiators_5 nodupkey out=bbb;
by ppn;
run;
**510 ppl with death date<indexdate, therefore the death dates are likely incorrect, must delete;



*At this stage there are 150,837 people with diagnosed T2DM who have started either Metformin or SU monotherapy after 1/7/13;

data diabetes.met_SU_initiators_6;
set diabetes.met_SU_initiators_5;
Age=(indexdate-dob)/365.25;
if Age<50 then agegp=0;
if 50<=Age<75 then agegp=1;
if Age>=75 then agegp=2;
if age<18 then delete;
if age>=100 then delete;
run;

proc sort data=diabetes.met_SU_initiators_6 nodupkey out=ggg;
by ppn;
run;
**150617 ppl over 18 years and under 100 yrs

**if diabetes diagnosis date is missing then use ndss  registration date as a proxy;
data diabetes.met_SU_initiators_7;
set diabetes.met_SU_initiators_6;
if diab_dx_date=. then diab_dx_date=ndss_reg_date;
run;

**setting up a variable for time between diagnosis and first Tx, ie duration of T2DM before start of follow up. If duration<0 this means that 
patient was treated with a T2DM medication before official diagnosis;
data diabetes.met_SU_initiators_8;
set diabetes.met_SU_initiators_7;
Duration=(indexdate-diab_dx_date)/365.25;
if Duration<=0 then Durationgp=0;
if 0<duration<=1 then durationgp=1;
if 1<duration<=2 then durationgp=2;
if 2<duration<=3 then durationgp=3;
if duration>3 then durationgp=4;
if supp_date<indexdate then delete;
run;

proc freq data=diabetes.met_SU_initiators_8;
tables durationgp; 
run;

data diabetes.met_SU_initiators_9 (keep= ppn indexdate);
set diabetes.met_SU_initiators_8;
run;

**the following will give a list of all the ppn's in the cohort and their index dates;
proc sort data=diabetes.met_SU_initiators_9 nodupkey out=diabetes.met_SU_initiators_10;
by ppn;
run;


**150,617 ppl initiating met or a su;




***SECTION 2: LOOKING AT THE NON-T2DM DRUG HX OF THE COHORT DURING THE 3 MONTHS PRIOR TO INDEXDATE;


data diabetes.full_dataset;
set 'G:\PBS_ Original_data_one big data set\pbs_extract_eo2015_1_148';
where spply_dt >= '01JUL12'd;
run;



data diabetes.full_dataset2 (keep=ppn Supp_date atc5 ITM_CD);
set diabetes.full_dataset;
supp_date=spply_dt;
ATC5=ATC_LVL_5_CD;
Item_code= ITM_CD;
run;

proc sort data=diabetes.full_dataset2 out=diabetes.full_dataset3;
by ppn ATC5;
run;

**merging patients and their indexdates with list of all meds given in the three months before the indexdate;
data diabetes.comorbs_last_3_months ;
merge diabetes.met_SU_initiators_10 (in=a) diabetes.full_dataset3 (in=b);
by ppn;
if a; 
run;


data diabetes.comorbs_last_3_months2 ;
set diabetes.comorbs_last_3_months ;
format supp_date date9.;
if  supp_date < (indexdate-365) then delete;
if supp_date> indexdate then delete;
run;



data diabetes.anti_psych (keep= ppn AP);
set diabetes.comorbs_last_3_months2 ;
if substr(ATC5,1,4)='N05A' and (indexdate-92)<=supp_date<=indexdate then AP=1;
if AP=1 then output;
run;
proc sort data=diabetes.anti_psych nodupkey out=diabetes.anti_psych_sort;
by ppn;
run;





data diabetes.syst_cort(keep= ppn syst_cort);
set diabetes.comorbs_last_3_months2 ;
if substr(ATC5,1,3)='H02' and (indexdate-92)<= supp_date <= indexdate then syst_cort=1;
if syst_cort=1 then output;
run;
proc sort data=diabetes.syst_cort nodupkey out=diabetes.syst_cort_sort;
by ppn;
run;

**merging all patients with the three classes of interest (Atypical antipsychotics, systemic corticosteroids and statins);
data diabetes.comorbs_last_3_months2 ;
merge diabetes.comorbs_last_3_months2 (in=a) diabetes.anti_psych_sort diabetes.syst_cort_sort;
by ppn;
if a; 
if AP=. then AP=0;
if syst_cort=. then syst_cort=0;
run;


*this modifies the original pbs item code map to distinguish betwen particular meds by item code';
data diabetes.comorbs_last_3_months3 ;
set diabetes.comorbs_last_3_months2 ;
length ATCmod $9.;
ATCmod=ATC5;
if ATC5='C07AB02' and ITM_CD in: ('01324Q', '01325R') then ATCmod='C07AB02_1'; /*metoprolol tartrate*/
if ATC5='C07AB02' and ITM_CD in:('08732N', '08733P', '08734Q', '08735R', '08818D') then ATCmod='C07AB02_2';/*metoprolol succinate*/
if ATC5=:'L01BA01' and ITM_CD in:('01622J', '01623K', '02272N') then ATCmod='L01BA01_1';/*methotrexate tabs*/
if ATC5='L01BA01' and ITM_CD in: ('01818Q', '02395C', '02396D', '04502Y', '04512L', '05873D', '05874E', '05875F', '05876G', '05962T', '05963W', '07250N', '07251P', 
'08850T', '08851W', '08852X', '08863L') then ATCmod='L01BA01_2'; /*methotrexate IV*/
if ATC5='L02BA01' and ITM_CD in: ('01880Y', '02109B', '02110C') then ATCmod='L02BA01_1'; /*tamoxifen cancer indication*/
if ATC5='L02BA01' and ITM_CD in: ('10911G') then ATCmod='L02BA01_2'; /*tamoxifen preventative indication*/
if ATC5='N03AX12' and ITM_CD in: ('04591P','04592Q','04593R','04594T','04595W') then ATCmod='N03AX12_1';
if ATC5='N03AX12' and ITM_CD in: ('08389M', '08559L', '01835N','08505P','01834M') then ATCmod='N03AX12_2';
if ATC5='N02BG' and ITM_CD in: ('02355Y', '02348N', '02363J', '02335X') then ATCmod='N03AX16';
if ATC5='L02AE03' and ITM_CD in: ('09065D', '09066E','09064C', '08093Y') then ATCmod='L02AE03_1';*goserelin for cancer';
if ATC5='L02AE' and ITM_CD in: ('09065D', '09066E','09064C') then ATCmod='L02AE03_1';*some of the item drug code map has them just as the first 4 letters';
if ATC5='L02AE03' and ITM_CD in: ('01454M') then ATCmod='L02AE03_2'; *goserelin for other indications';
if ATC5='L02AE02'  and ITM_CD in: ('08876E','08708H','08877F', '08709J', '10656W', '08859G', 
'08875D', '08707G','10963B', '10963B','10962Y', '10962Y') then ATCmod='L02AE02_1';*leuprorelin for cancer';
if ATC5='L02AE02' and ITM_CD in: ('10255R', '10256T') then ATCmod='L02AE02_2';*leuprorelin not for cancer';
if ATCmod='Z' or ATCmod='.' then delete;
run;



/**comorbidity scores**/
proc format;
	value $comorbf
	'B01AA03'-'B01AB06', 'B01AE07', 'B01AF01', 'B01AF02', 
	'B01AX05'													='01' /* Anticoag (Atrial fibrillation/flutter)*/ 
	'B01AC04'-'B01AC30'											='02' /* Antiplat (Cerebrovasc disease) */
	'C01AA05','C01BA01'-'C01BD01', 'C07AA07'					='03' /* Arrhythmia ?add propranolol C07AA05, dig can also be used for HF*/
	'G04CA02'-'G04CA03','G04CB01', 'G04CB02', 'C02CA01'			='04' /* BPH ?restrict to men only somehow*/ 
	'N05AN01'													='05' /* Bipolar */
	'C03DA04','C07AB07', 'C07AG02', 'C07AB12', 'C07AB02_2',
	'C09DX04'													='06' /* CHF=06 metoprolol (C07AB02_2)needs to be checked by item code as could be CR for CCF 
	(these item codes are for HT 01324Q 01325R)- HF specific betablockers+eplerenone*/
	'C03CA01'-'C03CC01'											='46' /* CHF A -diuretics*/
	'C09AA01'-'C09AA16','C09CA01'-'C09CA10' 					='47' /* CHF B * ACEI and ARBs*/
	'N06DA02'-'N06DA04','N06DX01'								='07' /* Dementia */
	'N06AA01'-'N06AG02','N06AX03'-'N06AX11','N06AX13'-'N06AX26' ='08' /* Depression */
	'A10AA01'-'A10BX08'											='09' /* Diabetes */
	'B03XA01'-'B03XA03','V03AE02', 'V03AE03', 'V03AE05' 		='10' /* End Stage Renal Disease ?include calcitriol and other vit d ('A11CC01'-'A11CC04')
	could aalso be used for other conditions*/
	'N03AA01'-'N03AX15', 'N03AX17'-'N03AX30'					='11' /* Epilepsy dont need to exclude atc N03AX16 for pregab as all 
	pbs item codes are matched to pain item code*/
	'S01EA01'-'S01EB03','S01EC03'-'S01EX02'						='12' /* Glaucoma */
	'M04AA01'-'M04AC01'											='13' /* Gout */
	'V03AE01'													='14' /* Hyperkalaemia */
	'C10AA01'-'C10BX12'											='15' /* Hyperlipidaemia */
	'C03AA01'-'C03BA11', 'C03BB04', 'C03DA01'-'C03DA03',
	'C03EA01'-'C03EA14', 'C09BA02'-'C09BA15',
	'C09DA01'-'C09DA09','C02AB01'-'C02AC05',
	'C02DB01'-'C02DB04', 'C03DB01'-'C03DB02'					='16' /* Hypertension ?add these item codes for metoprolol 01324Q 01325R 
	(doesnt have acei/arbs as they are in chf- see code incorprates them*/
	'H03AA01'-'H03AA05'											='17' /* Hypothyroidism */
	'C01DA02'-'C01DA70', 'C01DX16', 'C08EX02'					='18' /* IHD Angina */
	'C07AA01'-'C07AA06','C07AG01', 'C08CA01'-'C08DB01', 
	'C09DB01'-'C09DB08', 'C09DX01'-'C09DX03', 
	'C09BB02'-'C09BB12', 'C07AB03', 'C07AB02_1'					='19' /* ?'C10BX03' IHD Hypertension (Metoprolol tartrate(C07AB02_1)included */
	'A07EC01'-'A07EC04','A07EA01'-'A07EA02', 'A07EA06',
	'L04AA33'	    											='20' /* IBS Hydrocortisone Prednisolone Salazines budesonide vedoluzumab */
	'A07AA11'													='21' /* Liver Failure */
	'L01AA01'-'L01AX04', 'L01BA01_2', 'L01BA03'- 'L01XX53', 
	'L02BG03', 'L02BG04', 'L02BG06','L02BB01'-'L02BB04',
	'L02BX01'-'L02BX03', 'L04AX02', 'L04AX04', 'L04AX06', 
	'L02BA01_01', 'L02AE03_1'									='22' /* Malignancies - L01BA01_2 is for methotrexate injections only ; 
																L02BA01_01 is tamoxifen excluding code for prevention
																could add specific item codes for these atc codes 'L02AE01'-'L02AE05'
																?anymore to add*/
	'M05BA01'-'M05BB08','M05BX03','M05BX04', 'H05AA02'			='23' /* Osteoporosis Pagets doesnt inlcude raloxifene as can be used for breast cancer prevention*/
	'A09AA02'													='24' /* Pancreatic Insufficiency */
	'N04AA01'-'N04BX03'											='25' /* Parkinsons */
	'D05AA','D05BB01'-'D05BB02','D05AX02','D05AC01'-'D05AC51', 
	'D05AX52'													='26' /* Psoriasis */
	'N05AA01'-'N05AB02','N05AB06'-'N05AL07','N05AX01'-'N05AX17' ='27' /* Psychotic illness */
	'R03AC02'-'R03DC03', 'R03DX05'								='28' /* Reactive airways disease */

	'H02AB01'-'H02AB17'											='29' /* Steroid responsive diseases */
	'L04AA06','L04AA10','L04AA18','L04AD01','L04AD02','L04AC02'	='30' /* Transplant */
	'J04AB02', 'J04AC01'-'J04AM06'								='31' /* Tuberculosis */
	'N07BB01'-'N07BB99'											='32' /*Alcohol dependence*/
	'A02BA01'-'A02BX77'											='33' /*Gastric acid disorder*/
	'J05AF08', 'J05AF10', 'J05AF11'								='34' /*Hep B*/
	'J05AE11'-'J05AE15', 'J05AX14'-'J05AX68', 'J05AB04', 'L03AB11', 
	'L03AB60', 'L03AB61'										='35' /*Hep C re-check how do we distinguish between peg interferon being used for
	hep b or c and should we add others*/
	'J05AE01'-'J05AE10', 'J05AF01'-'J05AF07', 'J05AF09', 
	'J05AF12'-'J05AG05', 'J05AR01'-'J05AR19', 'J05AX07-J05AX09', 
	'J05AX12'													='36' /*HIV*/
	'R01AC01'-'R01AD60', 'R06AD02'-'R06AX27', 'R06AB04'			='37' /*Allergies*/
	'N05BA01'-'N05BA56', 'N05BE01'								='38' /*Anxiety and tension*/
	'H03BA02', 'H03BB01'										='39' /*Hyperthyroidism*/
	'B05BA01'-'B05BA10'											='40' /*Malnutrition*/
	'N02CA01'-'N02CX01'											='41' /*Migraine*/
	'M01AB01'-'M01AH06'											='42' /*Pain/Inflammation - checked*/
	'C02KX01'-'C02KX05' 										='43' /*Pulmonary hypertension Sildenafil (as PBS codes 9605M and 9547L)*/
	'N07BA01'-'N07BA03', 'N06AX12'								='44' /*Smoking cessation*/

	OTHER														='45';
run;


/**Setting up a new column for comorbidity score**/
data diabetes.comorbs_last_3_months4 ;
set diabetes.comorbs_last_3_months3 ;
comorb_cat=put(ATCmod,$comorbf.);
if comorb_cat = '.' then delete;
run;

data diabetes.comorbs_last_3_months5 ;
set diabetes.comorbs_last_3_months4 ;
cm_no=input(comorb_cat,5.);
run;
/**Setting up an array so that ppl can be classified into numbers of comorbidities**/

data diabetes.comorbs_last_3_months6 ;
set diabetes.comorbs_last_3_months5 ;
array cm[47] (47*0);
run;

data diabetes.comorbs_last_3_months7;
array cm[47];
set diabetes.comorbs_last_3_months6;
cm[cm_no]=1;
run;


proc sort data=diabetes.comorbs_last_3_months7;
by ppn cm_no;
run;



data diabetes.comorbs_last_3_months8 (drop=cm1-cm47 i cm_no);
set diabetes.comorbs_last_3_months7;
by ppn;
array cm[*] cm1-cm47;
array morb[*] morb1-morb47;
retain morb1-morb47;
if first.ppn=1 then do i=1 to 47;
morb[i]=cm[i];
end;
morb[cm_no]=1;
if last.ppn=1 then output;
run;


data diabetes.comorbs_last_3_months9 (drop=i morb46-morb47 ATCmod comorb_cat);
	array morb{*} morb1-morb47;
	set diabetes.comorbs_last_3_months8;
	if (morb{46}=1) and (morb{47}=1) then do;
		morb{6}=1;
	end;
   else if (morb{46}=1) or (morb{47}=1) then do;
		morb{16}=1;
	end;
	comorb_score=0;
         do i=1 to 45;
            if morb{i}=1 then
               do;
                  comorb_score=comorb_score+1;
               end;
         end;
    output;
run;

/**subtracting off 1 from all comorb scores to account for the fact that everyone has diabetes**/
data  diabetes.comorbs_last_3_months10;
set diabetes.comorbs_last_3_months9;
comorb_score_adj = comorb_score - 1;
run; 

proc freq data=diabetes.comorbs_last_3_months10;
tables comorb_score_adj;
run;
/**range of 0-11 comorbs**/

data diabetes.comorbs_last_3_months11;
set diabetes.comorbs_last_3_months10;
if comorb_score_adj =0 then comorb_scale = 0; **ie no other meds in the past 3 months;
if 0 < comorb_score_adj< 3 then comorb_scale = 1;  **ie only 1-2 meds in past 3 months;
if 2<comorb_score_adj<5 then comorb_scale = 2; **ie 3-4 meds in past 3 months;
if comorb_score_adj>=5 then comorb_scale = 3;  ** 5 or more meds in prior 3 months, ie polypharmacy;
run;

proc freq data=diabetes.comorbs_last_3_months11;
tables comorb_scale;
run;

proc means data=diabetes.comorbs_last_3_months11;
run;

data diabetes.comorbs_last_3_months12 ;
set diabetes.comorbs_last_3_months11;
if morb18=1 then Angina=1; else angina=0;
if morb2=1 then stroke=1; else stroke=0;
if morb6=1 then CHF=1; else CHF=0;
if morb44=1 then smoke=1; else smoke=0;
if morb8=1 then depression=1; else depression=0;
if morb15=1 then lipid=1; else lipid=0;
run;

data diabetes.comorbs_last_3_months13 (keep=ppn ap syst_cort comorb_score_adj comorb_scale chf smoke depression lipid) ;
set diabetes.comorbs_last_3_months12;
run;


**the following gives a list of all diab meds dispensed on or after the indexdate AND a summary of meds dispensed in the three months prior to the indexdate;
data diabetes.cohort_with_all_info;
merge diabetes.met_SU_initiators_8 (in=a) diabetes.comorbs_last_3_months13 (in=b);
by ppn;
if a; 
run;

proc sort data=diabetes.cohort_with_all_info nodupkey out=iii;
by ppn;
run;



** now to check missing values;
**422 ppl missing aria, 516 missing seifa and 3 missing sex- must delete- see next lines;


data diabetes.cohort_with_all_info3;
set diabetes.cohort_with_all_info;
if seifa_adv_ndss=. or aria_ndss=. or sex=. then delete;
if indexdate> '30Apr2015'd then delete; **must delete anyone with less than a full year of enrolment in the study;
if duration<0 then duration=0;
if durationgp=4 then durationgp=3;

run;


proc sort data=diabetes.cohort_with_all_info3 nodupkey out=diabetes.cohort_with_all_info4;
by ppn;
run;




proc freq data=diabetes.cohort_with_all_info4;
tables agegp sex comorb_scale aria_ndss durationgp lipid smoke chf depression ap syst_cort
seifa_adv_disadv_ndss indigenous_status2;
run;

data diabetes.cohort_with_all_info5;
set diabetes.cohort_with_all_info4;
where start_class=1;
run;

data diabetes.cohort_with_all_info6;
set diabetes.cohort_with_all_info4;
where start_class=2;
run;

proc freq data=diabetes.cohort_with_all_info6;
tables agegp sex comorb_scale aria_ndss seifa_adv_disadv_ndss chf smoke depression syst_cort
ap lipid durationgp indigenous_status2;
run;
proc univariate data=diabetes.cohort_with_all_info6;
var comorb_score_adj;
run;
proc univariate data=diabetes.cohort_with_all_info6;
var duration;
run;
**now 109573 ppl with complete records (no missing values);
****diabetes.cohort_with_all_info4- THIS IS the key file which contains the full cohort to be used in subsequent analyses- 
contains 109573;


proc means data=diabetes.cohort_with_all_info4;
run;

proc freq data=diabetes.cohort_with_all_info4;
tables  agegp sex comorb_scale aria_ndss durationgp
chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss;
run; 


***SECTION 3: Finding dates of discontinuation, 
identifying switches and add-ons for the metformin initiators;


**first, identify all the people who start on metformin monotherapy;
data analysis.metformin_initiators;
set diabetes.cohort_with_all_info3;
if start_class=1 then output;
run;

**102,737;

data analysis.metformin_initiators1;
set analysis.metformin_initiators;
where substr(ATC5,1,5)='A10BA' or substr(ATC5,1,5)='A10BD';
if itm_cd in ('11269D', '11298P', '11303X', '11310G', '11561L', '11578J', '11579K', 
'11583P', '11268B', '11305B') then delete;  
run;
**need to delete all combo products that do not contain metformin;

**102737 ppl in metformin cohort;
proc means data=bbbbbbbbb;
run;

proc univariate data=bbbbbbbbb;
var comorb_score_adj;
run;

proc freq data=bbbbbbbbb;
tables  agegp sex comorb_scale aria_ndss durationgp
chf smoke depression AP syst_cort lipid indigenous_status2;
run; 

**looking purely at all metformin (and metformin-containing) dispensings, to figure out if and when the person stopped metformin;
proc sort data=analysis.metformin_initiators1;
by ppn descending supp_date;
run;


data analysis.metformin_initiators2;
set analysis.metformin_initiators1;
format next_supp date9.;
next_supp=lag(supp_date);
run;

data analysis.metformin_initiators3;
set analysis.metformin_initiators2;
by ppn;
if first.ppn then next_supp=.;
daysbtw=next_supp-supp_date;
run;

proc sort data=analysis.metformin_initiators3;
by ppn supp_date;
run;
**Based on the Q3 values I am assigning an expected duration for each dispensing (supp_dur),  based on the quantity of packs dispensed;

data analysis.metformin_initiators4;
set analysis.metformin_initiators3;
**metformin monotherapy;
if itm_cd='01801T' then Q3=50;
if itm_cd='01801T' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*50/(60);
if itm_cd='02430X' then Q3=77;
if itm_cd='02430X' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*77/(100);
if itm_cd='03439B' then Q3=60;
if itm_cd='03439B' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*60/(60);
if itm_cd='08607B' then Q3=69;
if itm_cd='08607B' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*69/(90);
if itm_cd='09435N' then Q3=112;
if itm_cd='09435N' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*112/(120);

*met vilda;
if itm_cd='05474D' then Q3=39;
if itm_cd='05474D' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);
if itm_cd='05475E' then Q3=40;
if itm_cd='05475E' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);
if itm_cd='05476F' then Q3=42;
if itm_cd='05476F' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);

*met glib;
if itm_cd='08810Q' then Q3=60;
if itm_cd='08810Q' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(90);
if itm_cd='08811R' then Q3=55;
if itm_cd='08811R' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(90);
if itm_cd='08838E' then Q3=60;
if itm_cd='08838E' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(90);

*met rosi;
if itm_cd='09059T' then Q3=39;
if itm_cd='09059T' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='09060W' then Q3=45;
if itm_cd='09060W' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='09061X' then Q3=34;
if itm_cd='09061X' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);

*met sita;
if itm_cd='09449H' then Q3=38;
if itm_cd='09449H' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='09450J' then Q3=39;
if itm_cd='09450J' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='09451K' then Q3=39;
if itm_cd='09451K' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);

*met alo;
if itm_cd='10032B' then Q3=42;
if itm_cd='10032B' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='10033C' then Q3=38;
if itm_cd='10033C' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='10035E' then Q3=38;
if itm_cd='10035E' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);

*met lina;
if itm_cd='10038H' then Q3=40;
if itm_cd='10038H' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);
if itm_cd='10044P' then Q3=41;
if itm_cd='10044P' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);
if itm_cd='10045Q' then Q3=40;
if itm_cd='10045Q' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);

*met saxa;
if itm_cd='10048W' then Q3=39;
if itm_cd='10048W' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);
if itm_cd='10051B' then Q3=33;
if itm_cd='10051B' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(28);
if itm_cd='10055F' then Q3=34;
if itm_cd='10055F' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(28);

*met other sitas;
if itm_cd='10089B' then Q3=33;
if itm_cd='10089B' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(28);
if itm_cd='10090C' then Q3=42;
if itm_cd='10090C' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(56);

*met dapa;
if itm_cd='10510E' then Q3=35;
if itm_cd='10510E' then supp_dur= (PBS_RGLTN24_ADJST_QTY)* Q3/(56);
if itm_cd='10515K' then Q3=33;
if itm_cd='10515K' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(28);
if itm_cd='10516L' then Q3=32;
if itm_cd='10516L' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(28);

*met empa;
if itm_cd in ('10626G', '10627H', '10633P', '10639Y', '10640B', '10649L', '10650M', '10677Y') then Q3=30;
if itm_cd in ('10626G', '10627H', '10633P', '10639Y', '10640B', '10649L', '10650M', '10677Y') then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);
run;
*no missing entries in supp_dur column implies coding is accurate and no metformin containing products have been missed;

**before a "date of last dispensing" can be assigned for metformin, 
ONE grace period equal to Q3 will be added to account for the possibility of a 
hoarded box and another grace period will be added 
to account for missed doses/ non-adherence;
data analysis.metformin_initiators5;
set analysis.metformin_initiators4;;
format end_of_box_grace date9.;
end_of_box_grace= supp_date + 2*supp_dur;
if next_supp>end_of_box_grace then not_collected_in_time=1;
if next_supp=. and end_of_box_grace< (indexdate+365.25) then not_collected_in_time=1;
run;


** preventing metformin stopping dates from appearing as a result of people dying;
data analysis.metformin_initiators6;
set analysis.metformin_initiators5;
format Mend date9.;
if not_collected_in_time=1 then Mend= supp_date;
if ndi_dod ne '.' and  Mend>= ndi_dod then Mend= . ;
if Mend> (indexdate+365.25) then Mend=.;
run;



data analysis.metformin_initiators7;
set analysis.metformin_initiators6;
if Mend ne '.' then output;
run;

data analysis.metformin_initiators8 (keep=ppn end_of_box_grace Mend);
set analysis.metformin_initiators7;
run; 

 proc sort data=analysis.metformin_initiators8 nodupkey out=analysis.metformin_initiators9;
 by ppn;
 run;
 *41858 ppl with metformin end dates;

/**now looking at initiation dates for the first add-on therapy
step A- delete all lines where the dispensed drug is metformin, ie where class=1**/;

data analysis.metformin_add_on;
set diabetes.cohort_with_all_info3;
if start_class=1 then output;
run;
data analysis.metformin_add_ons;
set analysis.metformin_add_on;
if class = 1 then delete;
run;
proc sort data= analysis.metformin_add_ons;
by ppn supp_date;
run;

data analysis.metformin_add_ons2;
set analysis.metformin_add_ons;
retain Finit_date  Finit_class;
by ppn;
format Finit_date date9.;
if first.ppn then Finit_date =supp_date;
if first.ppn then Finit_class=class ;
run;

data analysis.metformin_add_ons3 (keep= ppn itm_cd Finit_date Finit_class);
set analysis.metformin_add_ons2;
if Finit_date> (indexdate +365.25) then delete;
run;

proc sort data=analysis.metformin_add_ons3 nodupkey out=analysis.metformin_add_ons3;
by ppn;
run;

/**23,163 ppl started their first add on medication to metformin within a year of metformin initiation (calling this "F")**/

**now going to have a look at the classes which have been switched in place of 
OR added in to metformin
the main problem here is re-coding combination metformin products 
to reflect the class of their non-metformin drug;

data analysis.metformin_add_ons4;
set analysis.metformin_add_ons3;
if Finit_class in ( '2', '4', '5', '6', '7', '8', '9') then New_class=Finit_class;
if itm_cd='08810Q' or itm_cd='08811R' or itm_cd='08838E' then New_class=2; **metformin/su combos;
if itm_cd='09059T' or itm_cd='09060W' or itm_cd='09061X' then New_class=5; **metformin / TZD combos;
if itm_cd='05474D' or itm_cd='05475E' or itm_cd='05476F' or itm_cd='09449H' or itm_cd='09450J' or itm_cd='09451K' or itm_cd='10032B' or itm_cd='10033C' or itm_cd='10035E'
or itm_cd='10038H' or itm_cd='10044P' or itm_cd='10045Q' or itm_cd='10048W' or itm_cd='10051B' or itm_cd='10055F'
or itm_cd='10089B' or itm_cd='10090C' then New_class=6;  **metformin DPP combos;
if itm_cd='10510E' or itm_cd='10515K' or itm_cd='10516L' or itm_cd='10626G' or itm_cd='10627H' or itm_cd='10633P' or itm_cd='10639Y' or itm_cd='10640B' or itm_cd='10649L' 
or itm_cd='10650M' or itm_cd='10677Y' then New_class=8; **metformin SGLT2Is;

run;


proc freq data=analysis.metformin_add_ons4;
tables new_class;
run;


proc sort data=analysis.metformin_initiators nodupkey out=analysis.metformin_initiators_sort;
by ppn;
run;
**Sorting the originaldata on metformin users by date order;

data analysis.all_dates_met;
merge analysis.metformin_initiators_sort (in=a) analysis.metformin_initiators9 (in=b) analysis.metformin_add_ons4 (in=c) ;
if a;
by ppn;
run;

**need to get rid of dups here;

proc sort data=analysis.all_dates_met nodupkey out=analysis.all_dates_met_nodups;
by ppn;
run;



/**looking at time to switch/ add-on from initial metformin monotherapy start date

Mend is the last dispensing date of metformin product before it is discontinued, "end of box grace" is equal to twice expected the duration of the final box of metformin 
if a new product is started after the Mend date and before the grace period after the final metformin dispensing, this is defined as a switch**/
data analysis.all_dates_met_add_swi;
set analysis.all_dates_met_nodups;
if Mend ne . and Mend<= Finit_date<= end_of_box_grace then possible_switch=1; else possible_switch=0;

if possible_switch=1 and Finit_class in ( '2', '4', '5', '6', '7', '8', '9') then switch=1; else switch=0;  **'3' is not included b/c the addition of a combo product 
containing metformin is an add on, not a switch;
if possible_switch=0 and Finit_class ne . then add=1; else add=0;
if duration<=0 then durationgp=0;
if 0<duration<=1 then durationgp=1;
if 1<duration<=2 then durationgp=2;
if duration>2 then durationgp=3;
if ARIA_NDSS=5 then ARIA_NDSS=4;

if comorb_score_adj<3 then co=0;
if 3<=comorb_score_adj<=5 then co=1;
if comorb_score_adj>5 then co=2;
run;




**now looking specifically at time to addition;
data analysis.all_dates_met_adition;
set analysis.all_dates_met_add_swi;
if add=1 then censor=0;
if add=1 then time=Finit_date-indexdate;

if switch=1 then censor=1;
if switch=1 then time= Finit_date-indexdate;

if add=0 and switch=0 and .< ndi_dod<= (indexdate+365.25) then censor=1;
if add=0 and switch=0 and . <ndi_dod<= (indexdate+365.25)  then time=ndi_dod- indexdate;

if add=0 and switch=0 and ndi_dod> (indexdate+365.25) then censor=1;
if add=0 and switch=0 and ndi_dod> (indexdate+365.25)  then time=365.25;

if add=0 and switch=0 and ndi_dod =. then censor=1;
if add=0 and switch=0 and ndi_dod =. then time=365.25;
logtime=log(time);




run;

proc sort data=analysis.all_dates_met_adition nodupkey out=analysis.all_dates_met_adition2;
by ppn;
run;


proc freq data=analysis.all_dates_met_adition2;
tables add switch;
run;

proc freq data=analysis.all_dates_met_adition2;
tables New_class;
where add=1;
run;

proc freq data=analysis.all_dates_met_adition2;
tables New_class;
where switch=1;
run;



/**completing table 1**/

proc means data=diabetes.cohort_with_all_info5;
run;

proc freq data=analysis.all_dates_met_adition;
tables  agegp sex co aria_ndss durationgp
chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2;
run; 



proc phreg data=analysis.all_dates_met_adition2 plots=survival;
class agegp sex comorb_scale aria_ndss durationgp CHF smoke depression syst_cort AP lipid seifa_adv_disadv_ndss indigenous_sTATUS2/ param=ref descending;
model time*add(0)= agegp sex comorb_scale aria_ndss durationgp CHF smoke depression syst_cort AP lipid seifa_adv_disadv_ndss indigenous_sTATUS2 /rl; 
run;

*finding the median time to addition is made more difficult by less than 50% of ppl intensifying after 1 year. 
Instead I will find the median time to addition only amongst those who had an addition;

data analysis.only_met_adds2;
set analysis.all_dates_met_adition;
where add=1;
run;






*mean time to add amongst adders is 135.06 days, median time is 104 days;


/* looking at time to first switch from initial metformin monotherapy start date **/
/** switch is defined as Mend date being BEFORE the F add-on date and Add is defined as the F add-on date being ON or AFTER the Mend date**/
data analysis.all_dates_met_switching;
set analysis.all_dates_met_add_swi;
if switch=1 then censor=0;
if switch=1 then time=Finit_date-indexdate;

if add=1 then censor=1;
if add=1 then time= Finit_date-indexdate;


if add=0 and switch=0 and .< ndi_dod<= (indexdate+365.25) then censor=1;
if add=0 and switch=0 and . <ndi_dod<= (indexdate+365.25)  then time=ndi_dod- indexdate;

if add=0 and switch=0 and ndi_dod> (indexdate+365.25) then censor=1;
if add=0 and switch=0 and ndi_dod> (indexdate+365.25)  then time=365.25;


if add=0 and switch=0 and ndi_dod =. then censor=1;
if add=0 and switch=0 and ndi_dod =. then time=365.25;

run;


proc phreg data=analysis.all_dates_met_switching plots=survival;
class agegp sex comorb_scale aria_ndss durationgp chf  smoke depression AP syst_cort lipid seifa_adv_disadv_ndss INDIGENOUS_STATUS2/ param=ref descending;
model time*switch(0)= agegp sex comorb_scale aria_ndss durationgp chf  smoke depression AP syst_cort lipid seifa_adv_disadv_ndss INDIGENOUS_STATUS2/rl ; 

run;




data analysis.only_met_adds;
set analysis.all_dates_met_adition;
where add=1;
run;
proc univariate data=analysis.only_met_adds;
var time;
run;



data analysis.only_met_switches;
set analysis.all_dates_met_switching;
where switch=1;
run;
proc univariate data=analysis.only_met_switches;
var time;
run;
**Among ppl who switched, the mean time to switch was 104 days and the median was 63 days;



proc freq data=analysis.all_dates_met_add_swi;
tables  agegp*add sex*add comorb_scale*add aria_ndss*add durationgp*add
chf*add smoke*add depression*add AP*add syst_cort*add statin*add seifa_adv_disadv_ndss*add;
run; 


proc freq data=analysis.all_dates_met_add_swi;
tables  agegp*switch sex*switch comorb_scale*switch aria_ndss*switch durationgp*switch
chf*switch smoke*switch depression*switch AP*switch syst_cort*switch statin*switch seifa_adv_disadv_ndss*switch;
run; 


























**Section 4: Looking at the SU cohort;




**first, identify all the people who start on metformin monotherapy;
data analysis.SU_initiators;
set diabetes.cohort_with_all_info3;
if start_class=2 then output;
run;


proc sort data=analysis.SU_initiators nodupkey out=a;
by ppn;
run;
**6836 ppl in su cohort;



proc univariate data=analysis.SU_initiators2;
var comorb_score_adj;
run;


data cccccccc;
set fffff;
if durationgp=4 then durationgp=3;
run;

proc means data=cccccccc;
run;

proc freq data=cccccccc;
tables  agegp sex comorb_scale aria_ndss durationgp
chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss;
run; 


**looking purely at all SU (and SU-containing) dispensings, to figure out if and when the person stopped metformin;

proc sort data=analysis.SU_initiators;
by ppn descending supp_date;
run;

data analysis.SU_initiators2;
set analysis.SU_initiators;
where substr(ATC5,1,5)='A10BB' or itm_cd in ('08810Q', '08811R', '08838E' );  *including the combination SU/metformin products;
format next_supp date9.;
next_supp=lag(supp_date);
run;



data analysis.SU_initiators3;
set analysis.SU_initiators2;
by ppn;
if first.ppn then next_supp=.;
daysbtw=next_supp-supp_date;
run;

proc sort data=analysis.SU_initiators3;
by ppn supp_date;
run;


**Based on these Q3 values I am assigning an expected duration for each dispensing (supp_dur),  based on the quantity of packs dispensed;



data analysis.SU_initiators4;
set analysis.SU_initiators3;
**SU monotherapy;
if itm_cd='02440K' then Q3=89;
if itm_cd='02440K' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(100);
if itm_cd='02449X' then Q3=100;
if itm_cd='02449X' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(100);
if itm_cd='02939Q' then Q3=103;
if itm_cd='02939Q' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(100);
if itm_cd='08450R' then Q3=38;
if itm_cd='08450R' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(30);
if itm_cd='08451T' then Q3=37;
if itm_cd='08451T' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(30);
if itm_cd='08452W' then Q3=40;
if itm_cd='08452W' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(30);
if itm_cd='08533D' then Q3=40;
if itm_cd='08533D' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(30);
if itm_cd='08535F' then Q3=101;
if itm_cd='08535F' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(100);
if itm_cd='09302N' then Q3=68;
if itm_cd='09302N' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(60);
if itm_cd='08810Q' then Q3=84;
if itm_cd='08810Q' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(90);
if itm_cd='08811R' then Q3=43;
if itm_cd='08811R' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(90);
if itm_cd='08838E' then Q3=84;
if itm_cd='08838E' then supp_dur= (PBS_RGLTN24_ADJST_QTY)*Q3/(90);
run;
*no missing entries in supp_dur column implies coding is accurate and no SU containing products have been missed;





**before a "date of last dispensing" can be assigned for metformin, TWO grace period equal to Q3 will be added to account for the possibility of a hoarded box and another grace period will be added 
to account for missed doses/ non-adherence;
data analysis.SU_initiators5;
set analysis.SU_initiators4;;
format end_of_box_grace date9.;
end_of_box_grace= supp_date + 2*supp_dur;
if next_supp>end_of_box_grace then not_collected_in_time=1;
if next_supp=. and end_of_box_grace< (indexdate+365.25) then not_collected_in_time=1;
run;

** preventing final SU dates of dispensing from appearing subsequent to people dying;
data analysis.su_initiators6;
set analysis.su_initiators5;
format Send date9.;
if not_collected_in_time=1 then Send= supp_date;
if ndi_dod ne '.' and  Send>= ndi_dod then Send= . ;
if Send> (indexdate+365.25) then Send=.;
run;



data analysis.su_initiators7;
set analysis.su_initiators6;
if Send ne '.' then output;
run;

data analysis.su_initiators8 (keep=ppn end_of_box_grace Send);
set analysis.su_initiators7;
run; 

 proc sort data=analysis.su_initiators8 nodupkey out=analysis.su_initiators9;
 by ppn;
 run;

/**4081 ppl stop SU at some stage if 2*supp_dur is used as the grace period

xxxx ppl stop SU at some stage if 2*supp_dur is used as the grace period **/






/**now looking at initiation dates for the first add-on therapy
step A- delete all lines where the dispensed drug is metformin, ie where class=1**/;

data analysis.SU_add_ons;
set analysis.SU_initiators;
if class = 2 then delete;
run;

proc sort data= analysis.SU_add_ons;
by ppn supp_date;
run;

data analysis.SU_add_ons2;
set analysis.SU_add_ons;
retain Finit_date  Finit_class;
by ppn;
format Finit_date date9.;
if first.ppn then Finit_date =supp_date;
if first.ppn then Finit_class=class ;
run;

data analysis.SU_add_ons3 (keep= ppn itm_cd Finit_date Finit_class);
set analysis.SU_add_ons2;
if Finit_date> (indexdate +365.25) then delete;
run;

proc sort data=analysis.SU_add_ons3 nodupkey out=analysis.SU_add_ons4;
by ppn;
run;

data analysis.SU_add_ons5;
set analysis.SU_add_ons4;
if Finit_class='3' and itm_cd in ('08810Q', '08811R', '08838E') then met_su_combo=1; else met_su_combo=0;
run;

/**2778 ppl started their first add on medication to metformin within a year of metformin initiation (calling this "F")**/










proc sort data=analysis.SU_initiators nodupkey out=analysis.SU_initiators_sort;
by ppn;
run;


**Merging the SU initiators with the important dates;

data analysis.all_dates_SU;
merge analysis.SU_initiators_sort (in=a) analysis.SU_initiators9 (in=b) analysis.SU_add_ons5 (in=c) ;
if a;
by ppn;
run;

**need to get rid of dups here;

proc sort data=analysis.all_dates_SU nodupkey out=analysis.all_dates_SU_nodups;
by ppn;
run;



/**looking at time to switch/ add-on from initial metformin SU start date

Send is the last dispensing date of SU product before the individual meets the criteria for discontinuing it, "end of box grace" is equal to twice expected the duration 
of the final box of SU. If a new product is started after the Send date and before the grace period after the final metformin dispensing, this is defined as a switch**/
data analysis.all_dates_SU_add_swi;
set analysis.all_dates_SU_nodups;
if Send ne . and Send<= Finit_date<= end_of_box_grace then possible_switch=1; else possible_switch=0;

if possible_switch=1 and Finit_class in ( '1', '3', '4', '5', '6', '7', '8', '9') and met_su_combo=0 then switch=1; else switch=0;  **we exclude met/su combo products as switches 
as they are actually add-ons. All other T2DM medications can meet the definition of a switch as long as they don't contain an SU;
if possible_switch=0 and Finit_class ne . then add=1; else add=0;
if duration<=0 then durationgp=0;
if 0<duration<=1 then durationgp=1;
if 1<duration<=2 then durationgp=2;
if duration>2 then durationgp=3;
if ARIA_NDSS=5 then ARIA_NDSS=4;

run;


proc freq data=analysis.all_dates_su_add_swi;
tables add;
run;


proc freq data=analysis.all_dates_su_add_swi;
tables switch;
run;

**863 ppl switch where grace period is 2* supp_dur;




**now looking specifically at time to addition;
data analysis.all_dates_su_adition;
set analysis.all_dates_su_add_swi;
if add=1 then censor=0;
if add=1 then time=Finit_date-indexdate;

if switch=1 then censor=1;
if switch=1 then time= Finit_date-indexdate;

if add=0 and switch=0 and .< ndi_dod<= (indexdate+365.25) then censor=1;
if add=0 and switch=0 and . <ndi_dod<= (indexdate+365.25)  then time=ndi_dod- indexdate;

if add=0 and switch=0 and ndi_dod> (indexdate+365.25) then censor=1;
if add=0 and switch=0 and ndi_dod> (indexdate+365.25)  then time=365.25;

if add=0 and switch=0 and ndi_dod =. then censor=1;
if add=0 and switch=0 and ndi_dod =. then time=365.25;

run;





proc phreg data=analysis.all_dates_su_adition plots=survival;
class agegp sex comorb_scale aria_ndss durationgp chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2 / param=ref descending;
model time*add(0)= agegp sex comorb_scale aria_ndss durationgp  chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2  /rl ; 

run;






/* looking at time to first switch from initial metformin monotherapy start date **/
/** switch is defined as Mend date being BEFORE the F add-on date and Add is defined as the F add-on date being ON or AFTER the Mend date**/
data analysis.all_dates_su_switching;
set analysis.all_dates_SU_add_swi;
if switch=1 then censor=0;
if switch=1 then time=Finit_date-indexdate;

if add=1 then censor=1;
if add=1 then time= Finit_date-indexdate;


if add=0 and switch=0 and .< ndi_dod<= (indexdate+365.25) then censor=1;
if add=0 and switch=0 and . <ndi_dod<= (indexdate+365.25)  then time=ndi_dod- indexdate;

if add=0 and switch=0 and ndi_dod> (indexdate+365.25) then censor=1;
if add=0 and switch=0 and ndi_dod> (indexdate+365.25)  then time=365.25;


if add=0 and switch=0 and ndi_dod =. then censor=1;
if add=0 and switch=0 and ndi_dod =. then time=365.25;

run;


proc phreg data=analysis.all_dates_su_switching plots=survival;
class agegp sex comorb_scale aria_ndss durationgp chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2 / param=ref descending;
model time*switch(0)= agegp sex comorb_scale aria_ndss durationgp chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2 /rl; 
run;


*looking at the different classes of medication that were added on to the initial thearapy;

data analysis.all_dates_SU_add_swi2;
set analysis.all_dates_SU_add_swi;
if add=1 and Finit_class in ( '1', '4', '5', '6', '7', '8', '9') then New_class=Finit_class;
if add=1 and Finit_class='3' and met_su_combo=1 then New_class='1'; *as adding an su/met product is equivalent to adding just metformin;
if add=1 and Finit_class='3' and met_su_combo=0 then New_class='3'; *if some other sort of combo product was added we will put it as category '3';
if switch=1 then New_class=Finit_class; **we already excluded met/su combo products from being classed as 
"switches" when we defined switch, therefore, no switcher will have a met/su product as their new medication (those who did receive a met/su combo would be classified 
as having received add-on therapy;
run;



proc freq data=analysis.all_dates_SU_add_swi2;
tables New_class;
where add=1;
run;

proc freq data=analysis.all_dates_SU_add_swi2;
tables New_class;
where switch=1;
run;

proc means data=analysis.all_dates_su_add_swi;
run;



data analysis.only_su_adds;
set analysis.all_dates_su_adition;
where add=1;
run;
proc univariate data=analysis.only_su_adds;
var time;
run;



data analysis.only_su_switches;
set analysis.all_dates_su_adition;
where switch=1;
run;
proc univariate data=analysis.only_su_switches;
var time;
run;



proc freq data=analysis.all_dates_SU_add_swi;
tables  agegp*add sex*add comorb_scale*add aria_ndss*add durationgp*add
chf*add smoke*add depression*add AP*add syst_cort*add statin*add seifa_adv_disadv_ndss*add;
run; 





proc freq data=analysis.all_dates_SU_add_swi;
tables  agegp*switch sex*switch comorb_scale*switch aria_ndss*switch durationgp*switch
chf*switch smoke*switch depression*switch AP*switch syst_cort*switch statin*switch seifa_adv_disadv_ndss*switch;
run; 






/**completing table 1**/

proc means data=diabetes.cohort_with_all_info5;
run;
proc freq data=diabetes.cohort_with_all_info5;
tables  agegp sex comorb_scale aria_ndss durationgp
chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2;
run; 
proc univariate data=diabetes.cohort_with_all_info5;
var comorb_score_adj duration;
run;



data met;
set diabetes.cohort_with_all_info5;
where start_class=1;
run;
proc means data=met;
run;
proc univariate data=met;
var comorb_score_adj duration;
run;


data su;
set diabetes.cohort_with_all_info5;
where start_class=2;
run;

proc freq data=su;
tables  agegp sex comorb_scale aria_ndss durationgp
chf smoke depression AP syst_cort lipid seifa_adv_disadv_ndss indigenous_status2;
run;
proc means data=su;
run;
proc univariate data=su;
var comorb_score_adj duration;
run;



/**table 3**/
proc freq data=analysis.all_dates_met_switching;
tables New_class;
where add=1;
run;

proc freq data=analysis.all_dates_met_switching;
tables New_class;
where switch=1;
run;
