with population as (
  select sc.subject_id,
    sc.hadm_id,
    id.icustay_id,
    id.gender,
    case when id.icustay_admit_age > 90 
      then 92.4
      else round(id.icustay_admit_age,2)
    end as age,
    id.icustay_intime, 
    round(id.icustay_los / 1400, 3) icustay_los_days,
    round(id.hospital_los / 1400, 3) hospital_los_days,
    id.icustay_expire_flg icu_exp_flg,
    id.hospital_expire_flg hosp_exp_flg,
    extract(day from id.dod - id.icustay_intime) survival_days,
    id.icustay_first_service careservice,
    id.weight_first weight,
    id.height,
    id.sapsi_first saps,
    id.sofa_first sofa
    
  from tbrennan.angus_sepsis_cohort sc
  join mimic2v26.icustay_detail id
    on sc.subject_id = id.subject_id 
    and sc.hadm_id = id.hadm_id
    
  where id.subject_icustay_seq = 1
)
--select * from population; -- icustay_id/subject_id 5156

, bmi as (
  select icustay_id,
    round(weight / power(height/100,2),2) bmi
    from population
)
--select * from bmi;

, demo as (
  select p.icustay_id,
       d.admission_type_descr, 
       d.admission_source_descr, 
        case 
          when ethnicity_descr  like '%WHITE%' then 'White' 
          when ethnicity_descr like '%BLACK%' then 'Black'
          when ethnicity_descr like '%HISPANIC%' then 'Hispanic'
          when ethnicity_descr like '%ASIAN%' then 'Asian'
          else 'Other'
        end as ethnicity
        
  from  population p, 
        mimic2v26.demographic_detail d
    
  where p.hadm_id =  d.hadm_id (+) 
)
--select * from demo;

, comorb as (

  select --s.subject_id, s.hadm_id, s.icustay_id,
       p.subject_id,
       p.hadm_id,
       p.icustay_id,
       e.congestive_heart_failure ,
       e.cardiac_arrhythmias,
       e.valvular_disease,
       e.pulmonary_circulation,
       e.peripheral_vascular,
       e.hypertension,
       e.paralysis,
       e.other_neurological,
       e.chronic_pulmonary,
       e.diabetes_uncomplicated,
       e.diabetes_complicated,
       e.hypothyroidism,
       e.renal_failure,
       e.liver_disease,
       e.peptic_ulcer,
       e.aids,
       e.lymphoma,
       e.metastatic_cancer,
       e.solid_tumor,
       e.rheumatoid_arthritis,
       e.coagulopathy,
       e.obesity,
       e.weight_loss,
       e.fluid_electrolyte,
       e.blood_loss_anemia,
       e.deficiency_anemias,
       e.alcohol_abuse,
       e.drug_abuse,
       e.psychoses,
       e.depression
  from  population p,  -- main table
      mimic2v26.comorbidity_scores e
  where p.hadm_id = e.hadm_id (+)

)
--select * from comorb;

, vasopressor_therapy as (
  select distinct p.subject_id,
        p.hadm_id,
        p.icustay_id, 
        m.itemid,
        case when m.dose <> 0 then 1
          else 0
        end as vasopressor  
    from population p
    left join mimic2v26.medevents m
         on m.icustay_id = p.icustay_id 
         and m.itemid in (42, 43, 44, 47, 51, 119, 120, 125, 127, 128)
)
--select * from vasopressor_therapy; -- rows 2632

/*
, pressors as (
  select distinct cd.icustay_id, 
      m.itemid,
      m.charttime,
      round(m.dose,2) dose,
      m.doseuom
    from tbrennan.echo_cohort cd 
    join mimic2v26.medevents m
         on cd.icustay_id = m.icustay_id 
         and m.itemid in (42, 43, 44, 47, 51, 119, 120, 125, 127, 128) 
         and m.dose<>0
)
--select count(icustay_id) from pressors; -- 848 rows


, pressor_start as (
  select distinct icustay_id, itemid,
    first_value(charttime) over (partition by icustay_id, itemid order by charttime) start_time
    from pressors
)
--select * from pressor_start;

, pressor_end as (
  select distinct icustay_id, itemid,
    first_value(charttime) over (partition by icustay_id, itemid order by charttime desc) end_time
    from pressors
)
--select * from pressor_end;

, pressor_therapy as (
  select distinct p.icustay_id, 
    p.itemid,
    p.dose,
    ps.start_time,
    pe.end_time,
    extract(day from pe.end_time - ps.start_time)*1440 + 
      extract(hour from pe.end_time - ps.start_time)*60 + 
        extract(minute from pe.end_time - ps.start_time) duration
    from pressors p 
    join pressor_start ps on p.icustay_id = ps.icustay_id and p.itemid = ps.itemid
    join pressor_end pe on p.icustay_id = pe.icustay_id and p.itemid = pe.itemid
    order by p.icustay_id, ps.start_time
)
--select count(icustay_id) from pressor_therapy;
*/

, final_therapy as (
  select distinct p.subject_id, p.icustay_id,
    first_value(t.vasopressor) over (partition by p.icustay_id order by t.vasopressor desc) vasopressor,
    sum(t.vasopressor) over (partition by p.icustay_id) no_pressors,
    case when v.seq = 1 then 1 
      else 0 
    end as ventilated,
    case when rc.rrt = 1 then 1 
      else 0 
    end as rrt
    from population p
    left join vasopressor_therapy t on t.icustay_id = p.icustay_id
    left join mimic2devel.ventilation v on v.icustay_id = p.icustay_id
    left join tbrennan.rrt_cohort rc on rc.icustay_id = p.icustay_id
)
--select * from final_therapy;

  
, assemble as (
  select p.*,
    b.bmi,
    d.admission_type_descr, 
    d.admission_source_descr, 
    d.ethnicity,
    e.congestive_heart_failure ,
    e.cardiac_arrhythmias,
    e.valvular_disease,
    e.pulmonary_circulation,
    e.peripheral_vascular,
    e.hypertension,
    e.paralysis,
    e.other_neurological,
    e.chronic_pulmonary,
    e.diabetes_uncomplicated,
    e.diabetes_complicated,
    e.hypothyroidism,
    e.renal_failure,
    e.liver_disease,
    e.peptic_ulcer,
    e.aids,
    e.lymphoma,
    e.metastatic_cancer,
    e.solid_tumor,
    e.rheumatoid_arthritis,
    e.coagulopathy,
    e.obesity,
    e.weight_loss,
    e.fluid_electrolyte,
    e.blood_loss_anemia,
    e.deficiency_anemias,
    e.alcohol_abuse,
    e.drug_abuse,
    e.psychoses,
    e.depression,
    ft.vasopressor,
    ft.no_pressors,
    ft.ventilated,
    ft.rrt
  from population p
  left join final_therapy ft on p.icustay_id = ft.icustay_id
  left join bmi b on b.icustay_id = ft.icustay_id
  left join demo d on d.icustay_id = ft.icustay_id
  left join comorb e on e.icustay_id = ft.icustay_id
)
select * from assemble;