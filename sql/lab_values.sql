
--select * from tbrennan.mimic2v26_labs_raw_48hr;
--select icustay_id, category, count(valuenum) no_readings from tbrennan.mimic2v26_labs_raw_48hr group by icustay_id, category order by category;

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
              'CHLORIDE' as chloride_no
              )
        )      

)
--select * from labs_analysis;
 

, labs_first as (
  select distinct subject_id, hadm_id, icustay_id,
    case 
      when category like 'HCT' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as hct_first,
    case 
      when category like 'WBC' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as wbc_first,
    case 
      when category like 'GLUCOSE' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as glucose_first,
    case 
      when category like 'HCO3' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as hco3_first,
    case 
      when category like 'POTASSIUM' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as k_first,
    case 
      when category like 'SODIUM' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as na_first,
    case 
      when category like 'BUN' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as bun_first,
    case 
      when category like 'CREATININE' then first_value(valuenum) over (partition by icustay_id order by post_adm) 
    end as creat_first
    from tbrennan.mimic2v26_labs_raw_48hr
)
select * from labs_first;

, labs_first as (
  select  *
    from 
      (select * from tbrennan.mimic2v26_labs_raw_48hr) 
        pivot (first_value(valuenum) over (partition icustay_id, post_adm)
            for category in (
              'HCT' as hct_med, 
              'WBC' as wbc_med, 
              'GLUCOSE' as glucose_med, 
              'HCO3' as hco3_med,
              'POTASSIUM' as k_med,
              'SODIUM' as na_med,
              'BUN' as bun_med,
              'CREATININE' as creat_med
              'PH' as ph_no,
              'LACTATE' as lactate_no,
              'TROPONIN' as troponin_no,
              'PLATELETS' as platelets_no,
              'PO2' as po2_no,
              'HGB' as hgb_no,
              'BNP' as bnp_no,
              'CHLORIDE' as chloride_no
              ))
)
select * from labs_med;
  
, labs_med as (
  select  *
    from 
      (select * from tbrennan.mimic2v26_labs_raw_48hr) 
        pivot (median(valuenum)
            for category in (
              'HCT' as hct_med, 
              'WBC' as wbc_med, 
              'GLUCOSE' as glucose_med, 
              'HCO3' as hco3_med,
              'POTASSIUM' as k_med,
              'SODIUM' as na_med,
              'BUN' as bun_med,
              'CREATININE' as creat_med))
)
--select * from labs_med;


, labs_min as (
  select  *
    from 
      (select * from tbrennan.mimic2v26_labs_raw_48hr) 
        pivot (min(valuenum)
            for category in (
              'HCT' as hct_min, 
              'WBC' as wbc_min, 
              'GLUCOSE' as glucose_min, 
              'HCO3' as hco3_min,
              'POTASSIUM' as k_min,
              'SODIUM' as na_min,
              'BUN' as bun_min,
              'CREATININE' as creat_min))
)
--select * from labvalues_min;

, labs_max as (
  select  *
    from 
      (select * from tbrennan.mimic2v26_labs_raw_48hr) 
        pivot (max(valuenum)
            for category in (
              'HCT' as hct_max, 
              'WBC' as wbc_max, 
              'GLUCOSE' as glucose_max, 
              'HCO3' as hco3_max,
              'POTASSIUM' as k_max,
              'SODIUM' as na_max,
              'BUN' as bun_max,
              'CREATININE' as creat_max))
)
--select * from labvalues_max;

, labs_std as (
  select  *
    from 
      (select * from tbrennan.mimic2v26_labs_raw_48hr) 
        pivot (stddev(valuenum)
            for category in (
              'HCT' as hct_std, 
              'WBC' as wbc_std, 
              'GLUCOSE' as glucose_std, 
              'HCO3' as hco3_std,
              'POTASSIUM' as k_std,
              'SODIUM' as na_std,
              'BUN' as bun_std,
              'CREATININE' as creat_std))
)
select * from labs_std;


, labs_slp as (
  select distinct subject_id, hadm_id, icustay_id,
    case 
      when category like 'HCT' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as hct_slp,
    case 
      when category like 'WBC' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as wbc_slp,
    case 
      when category like 'GLUCOSE' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as glucose_slp,
    case 
      when category like 'HCO3' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as hco3_slp,
    case 
      when category like 'POTASSIUM' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as k_slp,
    case 
      when category like 'SODIUM' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as na_slp,
    case 
      when category like 'BUN' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as bun_slp,
    case 
      when category like 'CREATININE' then round(regr_slope(post_adm,valuenum) over (partition by icustay_id),2) 
    end as creat_slp
    from tbrennan.mimic2v26_labs_raw_48hr
)
select * from labs_slp;
select count(*) missing_slp from labs_slp where hct_slp is null or wbc_slp is null or glucose_slp is null or hco3_slp is null or k_slp is null or na_slp is null or bun_slp is null or creat_slp is null; --32

, final as (
 select distinct
        fc.*,
        
        ld.hct_med,
        ln.hct_min,
        lx.hct_max,
        ls.hct_std,
        lp.hct_slp,
        
        ld.wbc_med,
        ln.wbc_min,
        lx.wbc_max,
        ls.wbc_std,
        lp.wbc_slp,
        
        ld.glucose_med,
        ln.glucose_min,
        lx.glucose_max,
        ls.glucose_std,
        lp.glucose_slp,
        
        ld.hco3_med,
        ln.hco3_min,
        lx.hco3_max,
        ls.hco3_std,
        lp.hco3_slp,
        
        ld.k_med,
        ln.k_min,
        lx.k_max,
        ls.k_std,
        lp.k_slp,
        
        ld.na_med,
        ln.na_min,
        lx.na_max,
        ls.na_std,
        lp.na_slp,
        
        ld.bun_med,
        ln.bun_min,
        lx.bun_max,
        ls.bun_std,
        lp.bun_slp,

        ld.br_med,
        ln.br_min,
        lx.br_max,
        ls.br_std,
        lp.br_slp,
        
        ld.creat_med,
        ln.creat_min,
        lx.creat_max,
        ls.creat_std,
        lp.creat_slp
        
  from tbrennan.mimic2v26_24k_vital_signs fc
  join labs_med ld on fc.icustay_id = ld.icustay_id 
  join labs_min ln on fc.icustay_id = ln.icustay_id 
  join labs_max lx on fc.icustay_id = lx.icustay_id 
  join labs_std ls on fc.icustay_id = ls.icustay_id 
    and ls.hct_std <> 0
    and ls.wbc_std <> 0
    and ls.glucose_std <> 0
    and ls.hc03_std <> 0
    and ls.k_std <> 0
    and ls.na_std <> 0
    and ls.bun_std <> 0
    and ls.creat_std <> 0
  join labs_slp lp on fc.icustay_id = lp.icustay_id 
)
select * from final;