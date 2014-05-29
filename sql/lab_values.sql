
create materialized view mimic2v26_48hr_vitals_labs as 

with labs_analysis as (
  select *
    from 
      (select subject_id, hadm_id, icustay_id, category, valuenum from tbrennan.mimic2v26_labs_raw_48hr) 
        pivot (count(valuenum)
            for category in (
              'HCT' as hct_no, 
              'WBC' as wbc_no, 
              'GLUCOSE' as glucose_no, 
              'HCO3' as hco3_no,
              'POTASSIUM' as k_no,
              'SODIUM' as na_no,
              'BUN' as bun_no,
              'CREATININE' as creat_no,
              'PH' as ph_no,
              'LACTATE' as lactate_no,
              'TROPONIN' as troponin_no,
              'PLATELETS' as platelets_no,
              'PO2' as po2_no,
              'HGB' as hgb_no,
              'BNP' as bnp_no,
              'CHLORIDE' as cl_no
              )
        )      

)
/*
select median(hct_no), stddev(hct_no),
      median(wbc_no), stddev(wbc_no),
      median(glucose_no), stddev(glucose_no),
      median(hco3_no), stddev(hco3_no),
      median(k_no), stddev(k_no),
      median(na_no), stddev(na_no),
      median(bun_no), stddev(bun_no),
      median(creat_no), stddev(creat_no),
      median(ph_no), stddev(ph_no),
      median(lactate_no), stddev(lactate_no),
      median(troponin_no), stddev(troponin_no),
      median(platelets_no), stddev(platelets_no),
      median(po2_no), stddev(po2_no),
      median(hgb_no), stddev(hgb_no),
      median(bnp_no), stddev(bnp_no),
      median(cl_no), stddev(cl_no)
      from labs_analysis;
*/

, labs_first_raw as (
  select distinct subject_id, hadm_id, icustay_id, 
    category,
    first_value(valuenum) over (partition by icustay_id, category order by post_adm) first_lab
    from tbrennan.mimic2v26_labs_raw_48hr
)
--select * from labs_first_raw order by icustay_id;

, labs_first as (
  select  *
    from 
      (select * from labs_first_raw) 
        pivot (median(first_lab)
            for category in (
              'HCT' as hct_first, 
              'WBC' as wbc_first, 
              'GLUCOSE' as glucose_first, 
              'HCO3' as hco3_first,
              'POTASSIUM' as k_first,
              'SODIUM' as na_first,
              'BUN' as bun_first,
              'CREATININE' as creat_first,
              'PH' as ph_first,
              'LACTATE' as lactate_first,
              'TROPONIN' as troponin_first,
              'PLATELETS' as platelets_first,
              'PO2' as po2_first,
              'HGB' as hgb_first,
              'BNP' as bnp_first,
              'CHLORIDE' as cl_first
              ))
)
--select * from labs_first;
  
, labs_med_raw as (
  select distinct subject_id, hadm_id, icustay_id, 
    category,
    median(valuenum) over (partition by icustay_id, category) med_lab
    from tbrennan.mimic2v26_labs_raw_48hr
)
--select * from labs_med_raw order by icustay_id;

, labs_med as (
  select  *
    from 
      (select * from tbrennan.labs_med_raw) 
        pivot (median(med_lab) 
            for category in (
              'HCT' as hct_med, 
              'WBC' as wbc_med, 
              'GLUCOSE' as glucose_med, 
              'HCO3' as hco3_med,
              'POTASSIUM' as k_med,
              'SODIUM' as na_med,
              'BUN' as bun_med,
              'CREATININE' as creat_med,
              'PH' as ph_med,
              'LACTATE' as lactate_med,
              'TROPONIN' as troponin_med,
              'PLATELETS' as platelets_med,
              'PO2' as po2_med,
              'HGB' as hgb_med,
              'BNP' as bnp_med,
              'CHLORIDE' as cl_med
              ))
)
--select * from labs_med order by icustay_id;

, labs_min_raw as (
  select distinct subject_id, hadm_id, icustay_id, 
    category,
    min(valuenum) over (partition by icustay_id, category) min_lab
    from tbrennan.mimic2v26_labs_raw_48hr
)


, labs_min as (
  select  *
    from 
      (select * from labs_min_raw) 
        pivot (median(min_lab)
            for category in (
              'HCT' as hct_min, 
              'WBC' as wbc_min, 
              'GLUCOSE' as glucose_min, 
              'HCO3' as hco3_min,
              'POTASSIUM' as k_min,
              'SODIUM' as na_min,
              'BUN' as bun_min,
              'CREATININE' as creat_min,
              'PH' as ph_min,
              'LACTATE' as lactate_min,
              'TROPONIN' as troponin_min,
              'PLATELETS' as platelets_min,
              'PO2' as po2_min,
              'HGB' as hgb_min,
              'BNP' as bnp_min,
              'CHLORIDE' as cl_min
              ))
)
--select * from labs_min order by icustay_id;

, labs_max_raw as (
  select distinct subject_id, hadm_id, icustay_id, 
    category,
    max(valuenum) over (partition by icustay_id, category) max_lab
    from tbrennan.mimic2v26_labs_raw_48hr
)

, labs_max as (
  select  *
    from 
      (select * from labs_max_raw) 
        pivot (median(max_lab)
            for category in (
              'HCT' as hct_max, 
              'WBC' as wbc_max, 
              'GLUCOSE' as glucose_max, 
              'HCO3' as hco3_max,
              'POTASSIUM' as k_max,
              'SODIUM' as na_max,
              'BUN' as bun_max,
              'CREATININE' as creat_max,
              'PH' as ph_max,
              'LACTATE' as lactate_max,
              'TROPONIN' as troponin_max,
              'PLATELETS' as platelets_max,
              'PO2' as po2_max,
              'HGB' as hgb_max,
              'BNP' as bnp_max,
              'CHLORIDE' as cl_max
              ))
)
--select * from labvalues_max;

, labs_std_raw as (
  select distinct subject_id, hadm_id, icustay_id, 
    category,
    round(stddev(valuenum) over (partition by icustay_id, category),2) std_lab
    from tbrennan.mimic2v26_labs_raw_48hr
)

, labs_std as (
  select *
    from 
      (select * from labs_std_raw) 
        pivot (median(std_lab)
            for category in (
              'HCT' as hct_std, 
              'WBC' as wbc_std, 
              'GLUCOSE' as glucose_std, 
              'HCO3' as hco3_std,
              'POTASSIUM' as k_std,
              'SODIUM' as na_std,
              'BUN' as bun_std,
              'CREATININE' as creat_std,
              'PH' as ph_std,
              'LACTATE' as lactate_std,
              'TROPONIN' as troponin_std,
              'PLATELETS' as platelets_std,
              'PO2' as po2_std,
              'HGB' as hgb_std,
              'BNP' as bnp_std,
              'CHLORIDE' as cl_std
              ))
)
--select * from labs_std order by icustay_id;

, labs_slp_raw as (
  select distinct subject_id, hadm_id, icustay_id, 
    category,
    round(regr_slope(post_adm,valuenum) over (partition by icustay_id, category),2) slp_lab
    from tbrennan.mimic2v26_labs_raw_48hr
)

, labs_slp as (
  select *
    from 
      (select * from labs_slp_raw) 
        pivot (median(slp_lab)
            for category in (
              'HCT' as hct_slp, 
              'WBC' as wbc_slp, 
              'GLUCOSE' as glucose_slp, 
              'HCO3' as hco3_slp,
              'POTASSIUM' as k_slp,
              'SODIUM' as na_slp,
              'BUN' as bun_slp,
              'CREATININE' as creat_slp,
              'PH' as ph_slp,
              'LACTATE' as lactate_slp,
              'TROPONIN' as troponin_slp,
              'PLATELETS' as platelets_slp,
              'PO2' as po2_slp,
              'HGB' as hgb_slp,
              'BNP' as bnp_slp,
              'CHLORIDE' as cl_slp
              ))
)
--select * from labs_slp order by icustay_id;

, final as (
 select distinct
        fc.*,
        
        lf.hct_first,
        ld.hct_med,
        ln.hct_min,
        lx.hct_max,
        ls.hct_std,
        lp.hct_slp,
        
        lf.wbc_first,
        ld.wbc_med,
        ln.wbc_min,
        lx.wbc_max,
        ls.wbc_std,
        lp.wbc_slp,
        
        lf.glucose_first,
        ld.glucose_med,
        ln.glucose_min,
        lx.glucose_max,
        ls.glucose_std,
        lp.glucose_slp,
        
        lf.hco3_first,
        ld.hco3_med,
        ln.hco3_min,
        lx.hco3_max,
        ls.hco3_std,
        lp.hco3_slp,
        
        lf.k_first,
        ld.k_med,
        ln.k_min,
        lx.k_max,
        ls.k_std,
        lp.k_slp,
        
        lf.na_first,
        ld.na_med,
        ln.na_min,
        lx.na_max,
        ls.na_std,
        lp.na_slp,
        
        lf.bun_first,
        ld.bun_med,
        ln.bun_min,
        lx.bun_max,
        ls.bun_std,
        lp.bun_slp,

        lf.creat_first,
        ld.creat_med,
        ln.creat_min,
        lx.creat_max,
        ls.creat_std,
        lp.creat_slp,
        
        lf.ph_first,
        ld.ph_med,
        ln.ph_min,
        lx.ph_max,
        ls.ph_std,
        lp.ph_slp,
        
        lf.lactate_first,
        ld.lactate_med,
        ln.lactate_min,
        lx.lactate_max,
        ls.lactate_std,
        lp.lactate_slp,

        lf.troponin_first,
        ld.troponin_med,
        ln.troponin_min,
        lx.troponin_max,
        ls.troponin_std,
        lp.troponin_slp,

        lf.platelets_first,
        ld.platelets_med,
        ln.platelets_min,
        lx.platelets_max,
        ls.platelets_std,
        lp.platelets_slp,

        lf.po2_first,
        ld.po2_med,
        ln.po2_min,
        lx.po2_max,
        ls.po2_std,
        lp.po2_slp,

        lf.hgb_first,
        ld.hgb_med,
        ln.hgb_min,
        lx.hgb_max,
        ls.hgb_std,
        lp.hgb_slp,

        lf.bnp_first,
        ld.bnp_med,
        ln.bnp_min,
        lx.bnp_max,
        ls.bnp_std,
        lp.bnp_slp,

        lf.cl_first,
        ld.cl_med,
        ln.cl_min,
        lx.cl_max,
        ls.cl_std,
        lp.cl_slp

  from tbrennan.mimic2v26_24hr_vital_signs fc
  join labs_first lf on fc.icustay_id = lf.icustay_id 
  join labs_med ld on fc.icustay_id = ld.icustay_id 
  join labs_min ln on fc.icustay_id = ln.icustay_id 
  join labs_max lx on fc.icustay_id = lx.icustay_id 
  join labs_std ls on fc.icustay_id = ls.icustay_id 
  join labs_slp lp on fc.icustay_id = lp.icustay_id 
)
select * from final;